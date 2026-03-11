// Copyright (c) 2026 The Gridcoin developers
// Distributed under the MIT software license, see the accompanying
// file COPYING or https://opensource.org/licenses/mit-license.php.

#ifndef GRIDCOIN_CONSENSUS_SHADOW_VALIDATOR_H
#define GRIDCOIN_CONSENSUS_SHADOW_VALIDATOR_H

#include "uint256.h"

#include <cstdint>
#include <string>

class CBlock;
class CBlockIndex;

namespace GRC {

//! Shadow-testing infrastructure for consensus rules validation.
//!
//! Provides flag state queries and structured logging for running the old
//! (ClaimValidator) and new (BlockRewardRules) implementations side-by-side.
//! The actual dispatch logic lives in GridcoinConnectBlock (validation.cpp),
//! which calls both implementations and reports results through this module.
//!
//! Controlled by startup flags:
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

//! Initialize the shadow validator from startup arguments.
//! Call once during init after argument parsing.
void InitShadowValidator();

//! Returns true if -consensusrulesimpl=new (BlockRewardRules is authoritative).
bool IsNewImplAuthoritative();

//! Returns true if shadow validation is enabled (-consensusrulesshadow=1).
bool IsShadowValidationEnabled();

//! Log a shadow comparison result. Called from GridcoinConnectBlock after
//! running the shadow implementation.
//!
//! \param height        Block height.
//! \param block_hash    Block hash.
//! \param auth_pass     Whether the authoritative implementation passed.
//! \param shadow_pass   Whether the shadow implementation passed.
//! \param auth_error    Error string from the authoritative implementation.
//! \param shadow_error  Error string from the shadow implementation.
//! \param auth_ms       Elapsed time for authoritative check in milliseconds.
//! \param shadow_ms     Elapsed time for shadow check in milliseconds.
//!
void LogShadowComparison(
    int height,
    const uint256& block_hash,
    bool auth_pass,
    bool shadow_pass,
    const std::string& auth_error,
    const std::string& shadow_error,
    int64_t auth_ms,
    int64_t shadow_ms);

//! Shut down shadow validator (flush and close log file if open).
void ShutdownShadowValidator();

} // namespace GRC

#endif // GRIDCOIN_CONSENSUS_SHADOW_VALIDATOR_H
