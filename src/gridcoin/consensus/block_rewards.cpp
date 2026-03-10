// Copyright (c) 2026 The Gridcoin developers
// Distributed under the MIT software license, see the accompanying
// file COPYING or https://opensource.org/licenses/mit-license.php.

#include "gridcoin/consensus/block_rewards.h"
#include "gridcoin/beacon.h"
#include "gridcoin/claim.h"
#include "gridcoin/mrc.h"
#include "gridcoin/quorum.h"
#include "gridcoin/sidestake.h"
#include "gridcoin/staking/exceptions.h"
#include "gridcoin/staking/reward.h"
#include "gridcoin/tally.h"
#include "chainparams.h"
#include "main.h"
#include "random.h"
#include "util.h"
#include "validation.h"

#include <algorithm>
#include <cassert>

using namespace GRC;

BlockRewardRules::BlockRewardRules(
    const CBlockIndex* pindex_prev,
    int block_version,
    int64_t block_time)
    : m_pindex_prev(pindex_prev)
    , m_block_version(block_version)
    , m_block_time(block_time)
    , m_block(nullptr)
    , m_pindex(nullptr)
    , m_stake_value_in(0)
    , m_total_claimed(0)
    , m_fees(0)
    , m_coin_age(0)
{
}

BlockRewardRules::BlockRewardRules(
    const CBlock& block,
    const CBlockIndex* pindex,
    CAmount stake_value_in,
    CAmount total_claimed,
    CAmount fees,
    uint64_t coin_age)
    : m_pindex_prev(pindex->pprev)
    , m_block_version(block.nVersion)
    , m_block_time(block.nTime)
    , m_block(&block)
    , m_pindex(pindex)
    , m_stake_value_in(stake_value_in)
    , m_total_claimed(total_claimed)
    , m_fees(fees)
    , m_coin_age(coin_age)
{
}

// -----------------------------------------------------------------------------
// Shared invariant computation
// -----------------------------------------------------------------------------

std::vector<BlockRewardRules::MandatorySidestakeSpec>
BlockRewardRules::ComputeEligibleMandatorySidestakes(
    const CTxDestination& coinstake_dest,
    CAmount total_owed_to_staker) const
{
    // No mandatory sidestakes before block version 13.
    if (m_block_version < 13) {
        return {};
    }

    std::vector<SideStake_ptr> active = GetSideStakeRegistry()
        .ActiveSideStakeEntries(SideStake::FilterFlag::MANDATORY, false);

    return ComputeEligibleMandatorySidestakes(coinstake_dest, total_owed_to_staker, active);
}

std::vector<BlockRewardRules::MandatorySidestakeSpec>
BlockRewardRules::ComputeEligibleMandatorySidestakes(
    const CTxDestination& coinstake_dest,
    CAmount total_owed_to_staker,
    const std::vector<SideStake_ptr>& active_sidestakes) const
{
    // No mandatory sidestakes before block version 13.
    if (m_block_version < 13) {
        return {};
    }

    std::vector<MandatorySidestakeSpec> specs;
    specs.reserve(active_sidestakes.size());

    for (const auto& ss : active_sidestakes) {
        MandatorySidestakeSpec spec;
        spec.dest = ss->GetDestination();
        spec.alloc = ss->GetAllocation();
        spec.required_amount = (spec.alloc * total_owed_to_staker).ToCAmount();

        // Dust elimination: suppress outputs below 1 CENT.
        // This matches the dust check in the miner's allocate_sidestakes lambda
        // and the validator's pre-filter loop. Written ONCE here.
        if (spec.required_amount < CENT) {
            spec.suppressed_reason = "dust (below CENT)";
        }
        // Coinstake-address filtering: suppress sidestakes to the staker's own
        // address. The miner skips these (returns funds via coinstake split
        // outputs instead). The validator must match this decision.
        else if (spec.dest == coinstake_dest) {
            spec.suppressed_reason = "matches coinstake destination";
        }

        specs.push_back(std::move(spec));
    }

    return specs;
}

std::vector<BlockRewardRules::MandatorySidestakeSpec>
BlockRewardRules::FilterEligible(
    const std::vector<MandatorySidestakeSpec>& specs)
{
    std::vector<MandatorySidestakeSpec> result;
    result.reserve(specs.size());

    for (const auto& s : specs) {
        if (!s.IsSuppressed()) {
            result.push_back(s);
        }
    }

    return result;
}

// -----------------------------------------------------------------------------
// Construct mode (miner)
// -----------------------------------------------------------------------------

bool BlockRewardRules::ConstructMandatorySidestakeOutputs(
    CMutableTransaction& mtx,
    const CTxDestination& coinstake_dest,
    CAmount total_owed_to_staker,
    CAmount& allocated_out) const
{
    auto eligible = FilterEligible(
        ComputeEligibleMandatorySidestakes(coinstake_dest, total_owed_to_staker));

    unsigned int output_limit = GetMandatorySideStakeOutputLimit(m_block_version);

    // Shuffle when over the limit — non-deterministic selection.
    // The validator cannot reproduce the shuffle and doesn't need to;
    // it matches against the eligible set regardless of order.
    if (eligible.size() > output_limit) {
        Shuffle(eligible.begin(), eligible.end(), FastRandomContext());
    }

    allocated_out = 0;
    unsigned int count = 0;

    for (const auto& spec : eligible) {
        if (count >= output_limit) break;

        // Amount comes from the spec — not recomputed here.
        CScript script;
        script.SetDestination(spec.dest);
        mtx.vout.push_back(CTxOut(spec.required_amount, script));
        allocated_out += spec.required_amount;
        ++count;
    }

    return true;
}

// -----------------------------------------------------------------------------
// Validate mode (validator)
// -----------------------------------------------------------------------------

bool BlockRewardRules::ValidateMandatorySidestakeOutputs(
    const CTransaction& coinstake,
    const CTxDestination& coinstake_dest,
    CAmount total_owed_to_staker,
    unsigned int mrc_start_index,
    std::string& error_out) const
{
    auto eligible = FilterEligible(
        ComputeEligibleMandatorySidestakes(coinstake_dest, total_owed_to_staker));

    unsigned int output_limit = GetMandatorySideStakeOutputLimit(m_block_version);
    unsigned int expected = std::min<unsigned int>(output_limit, eligible.size());

    // Track which spec entries have been matched. Each spec entry can match
    // at most one output — prevents a crafted block from satisfying the count
    // by duplicating one sidestake output and omitting another.
    std::vector<bool> matched(eligible.size(), false);
    unsigned int validated = 0;

    // Skip the empty output at index 0, stop before MRC outputs.
    for (unsigned int i = 1; i < mrc_start_index; ++i) {
        CTxDestination output_dest;
        if (!ExtractDestination(coinstake.vout[i].scriptPubKey, output_dest)) {
            error_out = strprintf("Coinstake vout[%u] has invalid destination", i);
            return false;
        }

        // Skip outputs to the coinstake destination — these are stake split
        // outputs, not mandatory sidestakes.
        if (output_dest == coinstake_dest) {
            continue;
        }

        // Scan eligible specs for an unmatched entry matching this output by
        // both destination AND exact amount. A voluntary sidestake to the same
        // address will have a different amount; the mandatory output has the
        // precisely computed value (allocation × total_owed_to_staker). This
        // correlation by address + amount distinguishes mandatory from voluntary
        // outputs to the same destination.
        for (unsigned int j = 0; j < eligible.size(); ++j) {
            if (matched[j]) continue;
            if (eligible[j].dest != output_dest) continue;

            if (coinstake.vout[i].nValue == eligible[j].required_amount) {
                matched[j] = true;
                ++validated;
                break;
            }
        }

        // Overflow check — should not happen, but be thorough.
        if (validated > output_limit) {
            error_out = strprintf(
                "Number of mandatory sidestakes (%u) exceeds protocol limit (%u)",
                validated, output_limit);
            return false;
        }
    }

    if (validated < expected) {
        error_out = strprintf(
            "Number of validated mandatory sidestakes (%u) is less than required (%u)",
            validated, expected);
        return false;
    }

    return true;
}

// =============================================================================
// Full claim validation (replaces ClaimValidator::Check())
// =============================================================================

bool BlockRewardRules::Check(std::string& error_out) const
{
    assert(m_block != nullptr); // Full validation constructor required.

    const Claim& claim = m_block->GetClaim();

    return claim.HasResearchReward()
        ? CheckResearcherClaim(error_out)
        : CheckNoncruncherClaim(error_out);
}

// -----------------------------------------------------------------------------
// CheckNoncruncherClaim
// -----------------------------------------------------------------------------

bool BlockRewardRules::CheckNoncruncherClaim(std::string& error_out) const
{
    CAmount mrc_rewards = 0;
    CAmount mrc_staker_fees = 0;
    CAmount mrc_fees = 0;
    CAmount out_stake_owed;
    unsigned int mrc_non_zero_outputs = 0;

    if (m_block_version >= 12
        && !CheckMRCRewards(mrc_rewards, mrc_staker_fees, mrc_fees,
                            mrc_non_zero_outputs, error_out))
    {
        return false;
    }

    if (CheckReward(0, out_stake_owed, mrc_staker_fees, mrc_fees,
                    mrc_rewards, mrc_non_zero_outputs, error_out))
    {
        return true;
    }

    if (GetBadBlocks().count(m_pindex->GetBlockHash())) {
        return true;
    }

    // error_out already set by CheckReward.
    return false;
}

// -----------------------------------------------------------------------------
// CheckResearcherClaim
// -----------------------------------------------------------------------------

bool BlockRewardRules::CheckResearcherClaim(std::string& error_out) const
{
    if (m_block_version >= 11) {
        return CheckResearchReward(error_out) && CheckBeaconSignature(error_out);
    }

    if (!CheckResearchRewardLimit(error_out)) return false;
    if (!CheckResearchRewardDrift(error_out)) return false;
    if (m_block_version <= 8) return true;
    if (!CheckClaimMagnitude(error_out)) return false;
    if (!CheckBeaconSignature(error_out)) return false;
    if (!CheckResearchReward(error_out)) return false;

    return true;
}

// -----------------------------------------------------------------------------
// CheckReward — core envelope and structural validation
// -----------------------------------------------------------------------------

bool BlockRewardRules::CheckReward(
    CAmount research_owed,
    CAmount& out_stake_owed,
    CAmount mrc_staker_fees_owed,
    CAmount mrc_fees,
    CAmount mrc_rewards,
    unsigned int mrc_non_zero_outputs,
    std::string& error_out) const
{
    out_stake_owed = GetProofOfStakeReward(m_coin_age, m_block_time, m_pindex);

    if (m_block_version >= 11) {
        if (m_total_claimed > research_owed + out_stake_owed + m_fees + mrc_fees + mrc_rewards) {
            error_out = strprintf(
                "Claim too high: total_claimed %s > %s = research %s + stake %s + fees %s + mrc_fees %s + mrc_rewards %s",
                FormatMoney(m_total_claimed),
                FormatMoney(research_owed + out_stake_owed + m_fees + mrc_fees + mrc_rewards),
                FormatMoney(research_owed),
                FormatMoney(out_stake_owed),
                FormatMoney(m_fees),
                FormatMoney(mrc_fees),
                FormatMoney(mrc_rewards));
            return false;
        }

        if (m_block_version >= 12) {
            const CTransaction& coinstake = m_block->vtx[1];
            const Claim& claim = m_block->GetClaim();

            bool foundation_mrc_sidestake_present =
                (claim.m_mrc_tx_map.size()
                 && FoundationSideStakeAllocation().IsNonZero()) ? true : false;

            unsigned int mrc_start_index = coinstake.vout.size()
                - mrc_non_zero_outputs
                - (unsigned int) foundation_mrc_sidestake_present;

            CAmount total_owed_to_staker = -m_stake_value_in;
            for (unsigned int i = 0; i < mrc_start_index; ++i) {
                total_owed_to_staker += coinstake.vout[i].nValue;
            }

            if (total_owed_to_staker > research_owed + out_stake_owed + m_fees + mrc_staker_fees_owed) {
                error_out = strprintf(
                    "Total owed to staker too high: %s > %s = research %s + stake %s + fees %s + mrc_staker_fees %s",
                    FormatMoney(total_owed_to_staker),
                    FormatMoney(research_owed + out_stake_owed + m_fees + mrc_staker_fees_owed),
                    FormatMoney(research_owed),
                    FormatMoney(out_stake_owed),
                    FormatMoney(m_fees),
                    FormatMoney(mrc_staker_fees_owed));
                return false;
            }

            // v13+ mandatory sidestake validation.
            if (m_block_version >= 13) {
                CTxDestination coinstake_dest;
                ExtractDestination(coinstake.vout[1].scriptPubKey, coinstake_dest);

                std::string ss_error;
                if (!ValidateMandatorySidestakeOutputs(
                        coinstake, coinstake_dest, total_owed_to_staker,
                        mrc_start_index, ss_error))
                {
                    error_out = ss_error;
                    return false;
                }
            }

            // Foundation MRC sidestake validation.
            if (foundation_mrc_sidestake_present) {
                if (coinstake.vout[mrc_start_index].nValue != mrc_fees - mrc_staker_fees_owed) {
                    error_out = strprintf(
                        "MRC Foundation sidestake amount incorrect: %s != mrc_fees %s - staker_fees %s",
                        FormatMoney(coinstake.vout[mrc_start_index].nValue),
                        FormatMoney(mrc_fees),
                        FormatMoney(mrc_staker_fees_owed));
                    return false;
                }

                CTxDestination foundation_dest;
                if (!ExtractDestination(coinstake.vout[mrc_start_index].scriptPubKey,
                                        foundation_dest))
                {
                    error_out = "MRC Foundation sidestake destination is invalid";
                    return false;
                }

                if (foundation_dest != FoundationSideStakeAddress()) {
                    error_out = "MRC Foundation sidestake destination does not match protocol";
                    return false;
                }
            }
        } // v12+

        return true;
    } // v11+

    // Blocks version 10 and below: floating-point with wiggle room.
    double subsidy = ((double)research_owed / COIN) * 1.25;
    subsidy += (double)out_stake_owed / COIN;

    CAmount max_owed = roundint64(subsidy * COIN) + m_fees;

    if (m_block_version <= 9) {
        max_owed += 1 * COIN;
    }

    if (m_total_claimed > max_owed) {
        error_out = strprintf("Claim %s exceeds max %s (legacy v%d)",
            FormatMoney(m_total_claimed), FormatMoney(max_owed), m_block_version);
        return false;
    }

    return true;
}

// -----------------------------------------------------------------------------
// CheckMRCRewards — validate MRC outputs in coinstake
// -----------------------------------------------------------------------------

bool BlockRewardRules::CheckMRCRewards(
    CAmount& mrc_rewards,
    CAmount& mrc_staker_fees,
    CAmount& mrc_fees,
    unsigned int& non_zero_outputs,
    std::string& error_out) const
{
    const CTransaction& coinstake = m_block->vtx[1];
    const Claim& claim = m_block->GetClaim();

    unsigned int mrc_outputs = 0;
    unsigned int mrc_output_limit = GetMRCOutputLimit(m_block_version, false);
    unsigned int mrc_claimed_outputs = claim.m_mrc_tx_map.size();

    if (mrc_claimed_outputs > mrc_output_limit) {
        error_out = strprintf("MRC claimed outputs %u exceeds limit %u",
            mrc_claimed_outputs, mrc_output_limit);
        return false;
    }

    if (mrc_output_limit > 0) {
        Fraction foundation_fee_fraction = FoundationSideStakeAllocation();

        for (const auto& tx : m_block->vtx) {
            for (const auto& mrc_entry : claim.m_mrc_tx_map) {
                if (mrc_entry.second == tx.GetHash()) {
                    for (const auto& contract : tx.GetContracts()) {
                        if (contract.m_type != ContractType::MRC) continue;

                        MRC mrc = contract.CopyPayloadAs<MRC>();

                        if (const CpidOption cpid = mrc.m_mining_id.TryCpid()) {
                            CBlockIndex* mrc_index = mapBlockIndex[mrc.m_last_block_hash];

                            const BeaconOption beacon = GetBeaconRegistry().TryActive(
                                *cpid, mrc_index->nTime);

                            if (beacon) {
                                if (!ValidateMRC(m_pindex->pprev, mrc)) {
                                    error_out = "An MRC in the claim failed to validate";
                                    return false;
                                }

                                CAmount mrc_reward = mrc.m_research_subsidy - mrc.m_fee;

                                CScript mrc_beacon_script;
                                mrc_beacon_script.SetDestination(beacon->GetAddress());

                                CAmount coinstake_mrc_reward = 0;

                                if (mrc_reward) {
                                    for (unsigned int i = coinstake.vout.size() - mrc_claimed_outputs;
                                         i < coinstake.vout.size(); ++i)
                                    {
                                        if (mrc_beacon_script == coinstake.vout[i].scriptPubKey) {
                                            coinstake_mrc_reward += coinstake.vout[i].nValue;
                                            ++non_zero_outputs;
                                        }
                                    }
                                }

                                if (coinstake_mrc_reward != mrc_reward) {
                                    error_out = strprintf(
                                        "MRC reward %s != coinstake output %s",
                                        FormatMoney(mrc_reward),
                                        FormatMoney(coinstake_mrc_reward));
                                    return false;
                                }

                                mrc_rewards += mrc_reward;
                                mrc_fees += mrc.m_fee;
                                mrc_staker_fees += mrc.m_fee
                                    - mrc.m_fee * foundation_fee_fraction.GetNumerator()
                                                / foundation_fee_fraction.GetDenominator();

                                ++mrc_outputs;
                            } // beacon
                        } // cpid
                    } // contracts

                    break;
                } // tx hash match
            } // mrc_tx_map
        } // block txns
    } // output_limit > 0

    if (mrc_outputs < mrc_claimed_outputs) {
        error_out = strprintf("Validated MRC claims %u < claimed %u",
            mrc_outputs, mrc_claimed_outputs);
        return false;
    }

    // NOTE: We do NOT signal uiInterface.MRCChanged() — shadow validation
    // must not trigger UI side effects.

    return true;
}

// -----------------------------------------------------------------------------
// CheckResearchReward — accrual lookup with newbie correction fallback
// -----------------------------------------------------------------------------

bool BlockRewardRules::CheckResearchReward(std::string& error_out) const
{
    const Claim& claim = m_block->GetClaim();

    CAmount research_owed = 0;
    CAmount mrc_rewards = 0;
    CAmount mrc_staker_fees = 0;
    CAmount mrc_fees = 0;
    unsigned int mrc_non_zero_outputs = 0;

    const CpidOption cpid = claim.m_mining_id.TryCpid();

    if (cpid) {
        research_owed = Tally::GetAccrual(*cpid, m_block_time, m_pindex);
    }

    if (m_block_version >= 12
        && !CheckMRCRewards(mrc_rewards, mrc_staker_fees, mrc_fees,
                            mrc_non_zero_outputs, error_out))
    {
        return false;
    }

    CAmount out_stake_owed;
    if (CheckReward(research_owed, out_stake_owed, mrc_staker_fees, mrc_fees,
                    mrc_rewards, mrc_non_zero_outputs, error_out))
    {
        return true;
    }

    // Newbie correction fallback — handles historical accrual snapshot bug.
    if (m_pindex->nHeight >= GetOrigNewbieSnapshotFixHeight() && cpid) {
        CAmount newbie_correction = Tally::GetNewbieSuperblockAccrualCorrection(
            *cpid, Quorum::CurrentSuperblock());

        research_owed += newbie_correction;

        if (CheckReward(research_owed, out_stake_owed, mrc_staker_fees, mrc_fees,
                        mrc_rewards, mrc_non_zero_outputs, error_out))
        {
            return true;
        }
    }

    // Testnet v9 exception: some blocks had bad interest claims masked by
    // short 10-block-span pending accrual.
    if (fTestNet && m_block_version <= 9) {
        std::string dummy;
        if (!CheckReward(0, out_stake_owed, 0, 0, 0, 0, dummy)) {
            return true;
        }
    }

    // Bad block exception.
    if (GetBadBlocks().count(m_pindex->GetBlockHash())) {
        return true;
    }

    // error_out already set by CheckReward.
    return false;
}

// -----------------------------------------------------------------------------
// CheckBeaconSignature — verify claim is signed by active beacon key
// -----------------------------------------------------------------------------

bool BlockRewardRules::CheckBeaconSignature(std::string& error_out) const
{
    const Claim& claim = m_block->GetClaim();
    const CpidOption cpid = claim.m_mining_id.TryCpid();

    if (!cpid) {
        error_out = "Non-researcher claim has no beacon signature";
        return false;
    }

    // v11+ uses block time for beacon expiration; v10 and below uses prev block time.
    const int64_t now = m_block_version >= 11 ? m_block_time : m_pindex->pprev->nTime;

    if (const BeaconOption beacon = GetBeaconRegistry().TryActive(*cpid, now)) {
        if (claim.VerifySignature(
            beacon->m_public_key,
            m_pindex->pprev->GetBlockHash(),
            m_block->vtx[1]))
        {
            return true;
        }
    }

    // Bad block exception.
    if (GetBadBlocks().count(m_pindex->GetBlockHash())) {
        return true;
    }

    // Testnet beaconalt range exception (historical bug, blocks 495352-600876).
    if (fTestNet
        && (m_pindex->nHeight >= 495352 && m_pindex->nHeight <= 600876))
    {
        return true;
    }

    error_out = strprintf("Beacon signature verification failed for CPID %s at height %d",
        claim.m_mining_id.ToString(), m_pindex->nHeight);
    return false;
}

// -----------------------------------------------------------------------------
// Legacy v9-v10 checks
// -----------------------------------------------------------------------------

bool BlockRewardRules::CheckResearchRewardLimit(std::string& error_out) const
{
    const Claim& claim = m_block->GetClaim();
    const CAmount max_reward = 12750 * COIN;

    if (claim.m_research_subsidy > max_reward) {
        error_out = strprintf("Research claim %s exceeds max %s for CPID %s",
            FormatMoney(claim.m_research_subsidy),
            FormatMoney(max_reward),
            claim.m_mining_id.ToString());
        return false;
    }

    return true;
}

bool BlockRewardRules::CheckResearchRewardDrift(std::string& error_out) const
{
    const Claim& claim = m_block->GetClaim();
    const CAmount reward_claimed = m_total_claimed - m_fees;
    CAmount drift_allowed = claim.m_research_subsidy * 0.15;

    if (drift_allowed < 10 * COIN) {
        drift_allowed = 10 * COIN;
    }

    if (claim.TotalSubsidy() + drift_allowed < reward_claimed) {
        error_out = strprintf("Reward claim %s exceeds allowed %s for CPID %s",
            FormatMoney(reward_claimed),
            FormatMoney(claim.TotalSubsidy() + drift_allowed),
            claim.m_mining_id.ToString());
        return false;
    }

    return true;
}

bool BlockRewardRules::CheckClaimMagnitude(std::string& error_out) const
{
    const Claim& claim = m_block->GetClaim();
    const double mag = Quorum::GetMagnitude(claim.m_mining_id).Floating();

    if (claim.m_magnitude > mag * 1.25) {
        error_out = strprintf("Magnitude claim %f exceeds superblock %f for CPID %s",
            claim.m_magnitude, mag, claim.m_mining_id.ToString());
        return false;
    }

    return true;
}
