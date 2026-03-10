// Copyright (c) 2026 The Gridcoin developers
// Distributed under the MIT software license, see the accompanying
// file COPYING or https://opensource.org/licenses/mit-license.php.

#include "gridcoin/consensus/shadow_validator.h"
#include "gridcoin/consensus/block_rewards.h"
#include "gridcoin/claim.h"
#include "gridcoin/mrc.h"
#include "main.h"
#include "util.h"
#include "util/time.h"
#include "validation.h"

#include <fstream>
#include <mutex>

using namespace GRC;

namespace {

//! Implementation selector: "old" or "new".
std::string g_consensus_impl = "old";

//! Whether to run the shadow (alternate) implementation alongside authoritative.
bool g_shadow_enabled = false;

//! Optional structured log file for shadow comparison results.
std::ofstream g_shadow_log_file;
std::mutex g_shadow_log_mutex;

//! Write a JSON-lines entry to the shadow log file (if open) and to debug log.
void LogShadowResult(
    int height,
    const uint256& block_hash,
    const std::string& component,
    bool auth_pass,
    bool shadow_pass,
    const std::string& auth_error,
    const std::string& shadow_error,
    int64_t auth_ms,
    int64_t shadow_ms)
{
    bool mismatch = (auth_pass != shadow_pass);

    if (mismatch) {
        LogPrintf("ERROR: ShadowValidator: MISMATCH at height %d hash %s component=%s: "
                  "auth(impl=%s)=%d shadow=%d auth_error='%s' shadow_error='%s' "
                  "auth_ms=%d shadow_ms=%d",
                  height, block_hash.ToString(), component,
                  g_consensus_impl, auth_pass, shadow_pass,
                  auth_error, shadow_error,
                  auth_ms, shadow_ms);
    } else {
        LogPrint(BCLog::LogFlags::VERBOSE,
                 "INFO: ShadowValidator: height %d component=%s match OK | "
                 "auth_ms=%d shadow_ms=%d",
                 height, component, auth_ms, shadow_ms);
    }

    // Write to structured log file if open.
    if (g_shadow_log_file.is_open()) {
        std::lock_guard<std::mutex> lock(g_shadow_log_mutex);

        g_shadow_log_file
            << "{\"height\":" << height
            << ",\"block_hash\":\"" << block_hash.ToString() << "\""
            << ",\"component\":\"" << component << "\""
            << ",\"auth_impl\":\"" << g_consensus_impl << "\""
            << ",\"auth_pass\":" << (auth_pass ? "true" : "false")
            << ",\"shadow_pass\":" << (shadow_pass ? "true" : "false");

        if (!auth_error.empty()) {
            g_shadow_log_file << ",\"auth_error\":\"" << auth_error << "\"";
        }
        if (!shadow_error.empty()) {
            g_shadow_log_file << ",\"shadow_error\":\"" << shadow_error << "\"";
        }

        g_shadow_log_file
            << ",\"auth_ms\":" << auth_ms
            << ",\"shadow_ms\":" << shadow_ms
            << "}\n";

        g_shadow_log_file.flush();
    }
}

//! Run BlockRewardRules mandatory sidestake validation on a block and compare
//! against the known-good result (old validator already passed).
void ShadowValidateMandatorySidestakes(
    const CBlock& block,
    const CBlockIndex* pindex,
    CAmount stake_value_in)
{
    // Only applies to v13+ blocks.
    if (block.nVersion < 13) return;

    const CTransaction& coinstake = block.vtx[1];
    const Claim& claim = block.GetClaim();

    // Reconstruct intermediate values the same way ClaimValidator does.
    CTxDestination coinstake_dest;
    if (!ExtractDestination(coinstake.vout[1].scriptPubKey, coinstake_dest)) {
        LogPrintf("ERROR: ShadowValidator: height %d: cannot extract coinstake destination",
                  pindex->nHeight);
        return;
    }

    // Compute mrc_start_index — same logic as CheckReward in validation.cpp.
    unsigned int mrc_claimed_outputs = claim.m_mrc_tx_map.size();
    bool foundation_mrc_sidestake_present = (mrc_claimed_outputs > 0
                                             && FoundationSideStakeAllocation().IsNonZero());

    // Count non-zero MRC outputs by scanning from the end.
    // The old validator uses mrc_non_zero_outputs from CheckMRCRewards, but we
    // can recount here: MRC outputs are at the end of vout, one per MRC claim
    // that has a non-zero net reward.
    unsigned int mrc_non_zero_outputs = 0;
    if (mrc_claimed_outputs > 0) {
        Fraction foundation_fee_fraction = FoundationSideStakeAllocation();

        for (const auto& tx : block.vtx) {
            for (const auto& mrc_entry : claim.m_mrc_tx_map) {
                if (mrc_entry.second == tx.GetHash()) {
                    for (const auto& contract : tx.GetContracts()) {
                        if (contract.m_type != ContractType::MRC) continue;

                        MRC mrc = contract.CopyPayloadAs<MRC>();

                        CAmount mrc_reward = mrc.m_research_subsidy - mrc.m_fee;
                        if (mrc_reward > 0) {
                            ++mrc_non_zero_outputs;
                        }
                    }
                    break;
                }
            }
        }
    }

    unsigned int mrc_start_index = coinstake.vout.size()
            - mrc_non_zero_outputs
            - (unsigned int) foundation_mrc_sidestake_present;

    // Compute total_owed_to_staker — same as CheckReward.
    CAmount total_owed_to_staker = -stake_value_in;
    for (unsigned int i = 0; i < mrc_start_index; ++i) {
        total_owed_to_staker += coinstake.vout[i].nValue;
    }

    // --- Run the new BlockRewardRules validation ---
    MilliTimer timer("shadow_mandatory_ss", false);

    BlockRewardRules rules(pindex->pprev, block.nVersion, block.nTime);
    std::string new_error;
    bool new_pass = rules.ValidateMandatorySidestakeOutputs(
        coinstake, coinstake_dest, total_owed_to_staker, mrc_start_index, new_error);

    auto times = timer.GetTimes("shadow_mandatory_ss");

    // The old validator already passed (we're called after ClaimValidator::Check()
    // succeeded), so the expected result from the new code is also pass.
    LogShadowResult(
        pindex->nHeight,
        pindex->GetBlockHash(),
        "mandatory_sidestakes",
        true,           // auth_pass (old already passed)
        new_pass,       // shadow_pass (new result)
        "",             // auth_error (none — old passed)
        new_error,      // shadow_error
        0,              // auth_ms (not timed separately — old ran inside ClaimValidator)
        times.elapsed_time);
}

} // anonymous namespace

// -----------------------------------------------------------------------------
// Public interface
// -----------------------------------------------------------------------------

void GRC::InitShadowValidator()
{
    g_consensus_impl = gArgs.GetArg("-consensusrulesimpl", "old");
    g_shadow_enabled = gArgs.GetBoolArg("-consensusrulesshadow", false);

    if (g_shadow_enabled) {
        LogPrintf("WARNING: Consensus shadow mode is active — this is a development/validation mode only. "
                  "Authoritative implementation: %s", g_consensus_impl);

        std::string log_path = gArgs.GetArg("-consensusshadowlog", "");
        if (!log_path.empty()) {
            g_shadow_log_file.open(log_path, std::ios::out | std::ios::app);
            if (g_shadow_log_file.is_open()) {
                LogPrintf("ShadowValidator: writing structured log to %s", log_path);
            } else {
                LogPrintf("ERROR: ShadowValidator: could not open shadow log file %s", log_path);
            }
        }
    }
}

bool GRC::ValidateClaimWithShadow(
    CBlock& block,
    const CBlockIndex* pindex,
    CAmount stake_value_in,
    CAmount total_claimed,
    CAmount fees,
    uint64_t coin_age)
{
    // --- Authoritative path: always run the old ClaimValidator ---
    // (Phase 1 will add the impl switch here; for Phase 0.5,
    // old is always authoritative.)
    //
    // ClaimValidator is a local class in validation.cpp, so we delegate to it
    // through the existing ValidateClaim function. We call it from
    // GridcoinConnectBlock which constructs ClaimValidator directly.
    //
    // NOTE: This function is NOT yet wired into GridcoinConnectBlock.
    // The wiring happens when we're ready to activate shadow mode.
    // For now, GridcoinConnectBlock continues to call ClaimValidator::Check()
    // directly, and this function exists as the future dispatch point.

    // --- Shadow path ---
    if (g_shadow_enabled && pindex->nHeight > nGrandfather) {
        ShadowValidateMandatorySidestakes(block, pindex, stake_value_in);
    }

    // The authoritative result is handled by the caller (GridcoinConnectBlock)
    // which still calls ClaimValidator::Check() directly.
    return true;
}

void GRC::ShutdownShadowValidator()
{
    if (g_shadow_log_file.is_open()) {
        g_shadow_log_file.close();
        LogPrintf("ShadowValidator: closed shadow log file");
    }
}
