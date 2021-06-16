// Copyright (c) 2014-2021 The Gridcoin developers
// Distributed under the MIT/X11 software license, see the accompanying
// file COPYING or http://www.opensource.org/licenses/mit-license.php.

#pragma once

#include "sync.h"
#include "uint256.h"

#include <string>
#include <vector>
#include <atomic>

namespace GRC {
class MinerStatus
{
public:
    MinerStatus();

    CCriticalSection cs_miner_status_lock;

    // Update STAKING_ERROR_STRINGS when adding or removing items.
    enum ReasonNotStakingCategory
    {
        NONE = 0x0,
        DISABLED_BY_CONFIGURATION = 0x1,
        NO_MATURE_COINS = 0x2,
        NO_COINS = 0x4,
        ENTIRE_BALANCE_RESERVED = 0x8,
        NO_UTXOS_AVAILABLE_DUE_TO_RESERVE = 0x10,
        WALLET_LOCKED = 0x20,
        TESTNET_ONLY = 0x40,
        OFFLINE = 0x80
    };

    // Space for more flags if necessary.
    uint16_t m_staking_status_flags;

    bool able_to_stake;

    uint64_t WeightSum, WeightMin, WeightMax;
    double ValueSum;
    int Version;
    uint64_t CreatedCnt;
    uint64_t AcceptedCnt;
    uint64_t KernelsFound;
    int64_t nLastCoinStakeSearchInterval;
    uint256 m_last_pos_tx_hash;

    uint64_t masked_time_intervals_covered = 0;
    uint64_t masked_time_intervals_elapsed = 0;

    double actual_cumulative_weight = 0.0;
    double ideal_cumulative_weight = 0.0;

    void Clear();

    bool SetReasonNotStakingFlag(ReasonNotStakingCategory not_staking_error);
    void ClearReasonNotStakingFlags();
    std::vector<std::string> GetReasonsNotStaking();
    std::string GetReasonsNotStakingString();
}; // MinerStatus
} // namespace GRC

extern GRC::MinerStatus g_miner_status;
