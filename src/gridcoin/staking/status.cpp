// Copyright (c) 2014-2021 The Gridcoin developers
// Distributed under the MIT/X11 software license, see the accompanying
// file COPYING or http://www.opensource.org/licenses/mit-license.php.

#include "gridcoin/staking/status.h"
#include "logging.h"

#include <algorithm>

using namespace GRC;

namespace {
//!
//! \brief Text descriptions to display when a wallet cannot stake.
//!
//! The sequence of this array matches the items enumerated on
//! MinerStatus::ReasonNotStakingCategory. Update this list as
//! well when those change.
//!
constexpr const char* STAKING_ERROR_STRINGS[] {
    "None",
    "Disabled by configuration",
    "No Mature Coins",
    "No coins",
    "Entire balance reserved",
    "No UTXOs available due to reserve balance",
    "Wallet locked",
    "Testnet-only version",
    "Offline",
};
} // Anonymous namespace

// -----------------------------------------------------------------------------
// Global Variables
// -----------------------------------------------------------------------------

MinerStatus g_miner_status;

// -----------------------------------------------------------------------------
// Class: MinerStatus
// -----------------------------------------------------------------------------

MinerStatus::MinerStatus(void)
{
    Clear();
    ClearReasonNotStakingFlags();
    CreatedCnt = AcceptedCnt = KernelsFound = 0;
}

void MinerStatus::Clear()
{
    WeightSum = ValueSum = WeightMin = WeightMax = 0;
    Version = 0;
    nLastCoinStakeSearchInterval = 0;
}

bool MinerStatus::SetReasonNotStakingFlag(ReasonNotStakingCategory not_staking_error)
{
    bool inserted = false;

    if (!(m_staking_status_flags & not_staking_error))
    {
        m_staking_status_flags |= not_staking_error;

        if (m_staking_status_flags > NO_MATURE_COINS) able_to_stake = false;

        inserted = true;
    }

    return inserted;
}

void MinerStatus::ClearReasonNotStakingFlags()
{
    m_staking_status_flags = NONE;
    able_to_stake = true;
}

std::vector<std::string> MinerStatus::GetReasonsNotStaking()
{
    std::vector<std::string> reasons;

    // The shift is the same as the index of the STAKING_ERROR_STRINGS.
    for (unsigned int shift = 0; shift < std::numeric_limits<decltype(m_staking_status_flags)>::digits; ++shift)
    {
        if ((decltype(m_staking_status_flags)) 1 & (m_staking_status_flags >> shift))
        {
            reasons.push_back(STAKING_ERROR_STRINGS[shift + 1]);
        }
    }

    return reasons;
}

std::string MinerStatus::GetReasonsNotStakingString()
{
    std::string output;
    const std::vector<std::string>& reasons = GetReasonsNotStaking();

    bool first = true;
    for (const auto& reason : reasons)
    {
        if (!first) output += "; ";
        output += reason;

        first = false;
    }

    return output;
}
