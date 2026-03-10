// Copyright (c) 2026 The Gridcoin developers
// Distributed under the MIT software license, see the accompanying
// file COPYING or https://opensource.org/licenses/mit-license.php.

#include "gridcoin/consensus/block_rewards.h"
#include "gridcoin/sidestake.h"
#include "main.h"
#include "random.h"
#include "util.h"
#include "validation.h"

#include <algorithm>

using namespace GRC;

BlockRewardRules::BlockRewardRules(
    const CBlockIndex* pindex_prev,
    int block_version,
    int64_t block_time)
    : m_pindex_prev(pindex_prev)
    , m_block_version(block_version)
    , m_block_time(block_time)
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

        // Scan eligible specs for an unmatched entry with this destination.
        // O(n*m) but both n and m are tiny (mandatory SS limit is 4).
        for (unsigned int j = 0; j < eligible.size(); ++j) {
            if (matched[j]) continue;
            if (eligible[j].dest != output_dest) continue;

            if (coinstake.vout[i].nValue >= eligible[j].required_amount) {
                matched[j] = true;
                ++validated;
            } else {
                error_out = strprintf(
                    "Mandatory sidestake vout[%u] to %s: actual %s < required %s",
                    i, EncodeDestination(output_dest),
                    FormatMoney(coinstake.vout[i].nValue),
                    FormatMoney(eligible[j].required_amount));
                return false;
            }
            break; // One match per output
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
