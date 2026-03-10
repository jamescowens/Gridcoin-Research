// Copyright (c) 2026 The Gridcoin developers
// Distributed under the MIT software license, see the accompanying
// file COPYING or https://opensource.org/licenses/mit-license.php.

#ifndef GRIDCOIN_CONSENSUS_SHADOW_VALIDATOR_H
#define GRIDCOIN_CONSENSUS_SHADOW_VALIDATOR_H

#include "amount.h"

#include <string>

class CBlock;
class CBlockIndex;

namespace GRC {

//! Shadow-testing facade for consensus rules validation.
//!
//! This provides a thin dispatch layer that can run both old (ClaimValidator)
//! and new (BlockRewardRules) implementations side-by-side, comparing results
//! at every block. Controlled by startup flags:
//!
//!   -consensusrulesimpl=<old|new>   Which implementation is authoritative
//!   -consensusrulesshadow=<0|1>     Whether to run the alternate for comparison
//!   -consensusshadowlog=<path>      Write structured JSON-lines comparison log
//!
//! The shadow path never affects the authoritative consensus result. Mismatches
//! are logged at ERROR level (and optionally to the structured log file).
//!
//! After cutover is complete and shadow has run clean, this entire file is
//! deleted along with the startup flag registrations.
//!
//! \sa #2880 (consensus rules unification issue)
//!

//! Results from a single validation pass, capturing all output values
//! for comparison between old and new implementations.
struct ClaimValidationResult
{
    bool pass = false;

    // CheckReward outputs
    CAmount stake_owed = 0;

    // CheckMRCRewards outputs
    CAmount mrc_rewards = 0;
    CAmount mrc_staker_fees = 0;
    CAmount mrc_fees = 0;
    unsigned int mrc_non_zero_outputs = 0;

    // Mandatory sidestake outputs (v13+)
    unsigned int mandatory_sidestakes_validated = 0;
    unsigned int mandatory_sidestakes_expected = 0;

    std::string error;
};

//! Initialize the shadow validator from startup arguments.
//! Call once during init after argument parsing.
void InitShadowValidator();

//! Run the authoritative claim validation, optionally with shadow comparison.
//!
//! This replaces the direct ClaimValidator construction in GridcoinConnectBlock.
//! Internally constructs ClaimValidator (old path) and/or BlockRewardRules
//! (new path) as needed based on the -consensusrulesimpl and
//! -consensusrulesshadow flags.
//!
//! \return true if the authoritative implementation accepts the claim.
//!
bool ValidateClaimWithShadow(
    CBlock& block,
    const CBlockIndex* pindex,
    CAmount stake_value_in,
    CAmount total_claimed,
    CAmount fees,
    uint64_t coin_age);

//! Shut down shadow validator (flush and close log file if open).
void ShutdownShadowValidator();

} // namespace GRC

#endif // GRIDCOIN_CONSENSUS_SHADOW_VALIDATOR_H
