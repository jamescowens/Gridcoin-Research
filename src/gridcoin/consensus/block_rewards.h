// Copyright (c) 2026 The Gridcoin developers
// Distributed under the MIT software license, see the accompanying
// file COPYING or https://opensource.org/licenses/mit-license.php.

#ifndef GRIDCOIN_CONSENSUS_BLOCK_REWARDS_H
#define GRIDCOIN_CONSENSUS_BLOCK_REWARDS_H

#include "amount.h"
#include "gridcoin/consensus/mutable_transaction.h"
#include "gridcoin/sidestake.h"
#include "script.h"

#include <string>
#include <vector>

class CBlockIndex;
class CTransaction;

namespace GRC {

class Claim;
class Cpid;

//! Unified consensus rules for block reward construction and validation.
//!
//! This class provides a single source of truth for the consensus rules that
//! govern coinstake output construction (miner) and verification (validator).
//! Both modes consume the same shared spec computations, eliminating the class
//! of bugs where miner and validator implementations drift apart (see #2848).
//!
//! The class operates in two modes:
//!   - **Construct** — used by the miner to build coinstake outputs.
//!     Methods take CMutableTransaction& and mutate it.
//!   - **Validate** — used by the validator to verify coinstake outputs.
//!     Methods take const CTransaction& and read from it.
//!
//! Both modes share the same invariant computation (the "spec") which is the
//! single point where eligible sets, amounts, and suppression decisions are
//! determined. Neither the construct nor validate path independently re-queries
//! registries or recomputes amounts — they consume the spec.
//!
//! \sa #2880 (consensus rules unification issue)
//! \sa #2877 (PSGT plan — CMutableTransaction split)
//!
class BlockRewardRules
{
public:
    BlockRewardRules(
        const CBlockIndex* pindex_prev,
        int block_version,
        int64_t block_time);

    // --- Shared spec types ---------------------------------------------------

    //! A single eligible mandatory sidestake with pre-computed required amount.
    //!
    //! Rounding semantics: Allocation inherits from Fraction, which is quantized
    //! to 1/10000 increments and simplified at construction. ToCAmount() uses
    //! integer division (truncation toward zero for positive values). The dust
    //! threshold comparison (required_amount < CENT) is applied after truncation,
    //! matching existing consensus behavior.
    struct MandatorySidestakeSpec
    {
        CTxDestination dest;
        Allocation alloc;
        CAmount required_amount;         //!< (alloc * total_owed_to_staker).ToCAmount()

        //! Non-empty if this entry was filtered out (dust, address match).
        //! For debug/test visibility only — MUST NOT affect consensus behavior.
        //! Only used for logging and assertions.
        std::string suppressed_reason;

        bool IsSuppressed() const { return !suppressed_reason.empty(); }
    };

    // --- Shared invariant computations (specs) -------------------------------

    //! Compute the eligible mandatory sidestakes after dust elimination and
    //! coinstake-address filtering. Returns a fully-resolved spec — the single
    //! source of truth for which sidestakes apply and what their required
    //! amounts are.
    //!
    //! Both Construct and Validate consume this spec rather than independently
    //! re-querying the registry. If the eligible set computation or amount
    //! calculation changes, it changes once, and both modes inherit it.
    //!
    //! The returned vector includes ALL mandatory sidestakes (including
    //! suppressed ones) so that filtering decisions are visible to tests and
    //! debug logging. Use FilterEligible() to get only non-suppressed entries.
    //!
    //! \param coinstake_dest  The destination of the coinstake output (vout[1]).
    //! \param total_owed_to_staker  Net value of non-MRC outputs minus input.
    //!
    std::vector<MandatorySidestakeSpec> ComputeEligibleMandatorySidestakes(
        const CTxDestination& coinstake_dest,
        CAmount total_owed_to_staker) const;

    //! Overload accepting an explicit list of active mandatory sidestakes
    //! instead of querying the global registry. This enables direct unit
    //! testing of the spec computation with controlled inputs.
    //!
    std::vector<MandatorySidestakeSpec> ComputeEligibleMandatorySidestakes(
        const CTxDestination& coinstake_dest,
        CAmount total_owed_to_staker,
        const std::vector<SideStake_ptr>& active_sidestakes) const;

    //! Filter a spec vector to only non-suppressed (eligible) entries.
    static std::vector<MandatorySidestakeSpec> FilterEligible(
        const std::vector<MandatorySidestakeSpec>& specs);

    // --- Construct-mode methods (miner) --------------------------------------

    //! Select and create mandatory sidestake outputs on the coinstake.
    //!
    //! Calls ComputeEligibleMandatorySidestakes() to get the spec, then
    //! shuffles if over the output limit (non-deterministic — construct only).
    //! Appends outputs to mtx.vout.
    //!
    //! \param[in,out] mtx              The mutable coinstake transaction.
    //! \param[in]     coinstake_dest   Destination of the coinstake (vout[1]).
    //! \param[in]     total_owed_to_staker  Net staker reward for allocation.
    //! \param[out]    allocated_out    Total amount allocated to sidestakes.
    //! \return true on success.
    //!
    bool ConstructMandatorySidestakeOutputs(
        CMutableTransaction& mtx,
        const CTxDestination& coinstake_dest,
        CAmount total_owed_to_staker,
        CAmount& allocated_out) const;

    // --- Validate-mode methods (validator) ------------------------------------

    //! Verify mandatory sidestake outputs exist with correct amounts.
    //!
    //! Calls ComputeEligibleMandatorySidestakes() to get the spec, then
    //! enumerates actual coinstake outputs and matches against the eligible
    //! set using matched-flags to prevent double-counting.
    //!
    //! \param[in]  coinstake           The (immutable) coinstake transaction.
    //! \param[in]  coinstake_dest      Destination of the coinstake (vout[1]).
    //! \param[in]  total_owed_to_staker  Net staker reward for allocation.
    //! \param[in]  mrc_start_index     Index where MRC outputs begin.
    //! \param[out] error_out           Descriptive error on failure.
    //! \return true if all required mandatory sidestakes are present and valid.
    //!
    bool ValidateMandatorySidestakeOutputs(
        const CTransaction& coinstake,
        const CTxDestination& coinstake_dest,
        CAmount total_owed_to_staker,
        unsigned int mrc_start_index,
        std::string& error_out) const;

private:
    const CBlockIndex* m_pindex_prev;
    int m_block_version;
    int64_t m_block_time;
};

} // namespace GRC

#endif // GRIDCOIN_CONSENSUS_BLOCK_REWARDS_H
