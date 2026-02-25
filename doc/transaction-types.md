# Gridcoin Transaction Types

This document explains the transaction type labels shown in the Gridcoin wallet's
transaction history and overview pages.

## Regular Transactions

| Label | Description |
|-------|-------------|
| **Sent to** | Funds you manually sent to another address. Requires an unlocked wallet. |
| **Received with** | Funds received at one of your labeled addresses. |
| **Received from** | Funds received from an address not in your address book. |
| **Payment to yourself** | A transaction that sends funds back to your own wallet (e.g. UTXO consolidation or change). |

## Staking Rewards

These transactions are generated automatically when your wallet stakes a block.
Your wallet must be encrypted and unlocked for staking only (or fully unlocked)
for staking to occur, but staking transactions are created by the staking process
itself — they are not manual sends.

| Label | Description |
|-------|-------------|
| **Mined - PoS** | You earned a Proof of Stake reward by staking a block. |
| **Mined - PoS+RR** | You earned a Proof of Stake reward combined with BOINC research rewards by staking a block. |
| **Mined - Superblock** | You earned a reward by staking a superblock (the periodic consensus snapshot of network research statistics). |
| **Mined - Orphaned** | You staked a block, but it was orphaned — another block at the same height was accepted by the network instead. No funds were gained or lost. |
| **Mined - Unknown** | A mined transaction whose specific type could not be determined. This should not normally appear. |

## Side Stakes

Side stakes are automatic reward distributions configured by stakers. When you
stake a block, a portion of your reward can be automatically sent to configured
side stake addresses (e.g. for pool operators, foundations, or personal
distribution). **These are not manual transactions.**

| Label | Description |
|-------|-------------|
| **PoS Side Stake Received** | You received a side stake allocation from another staker's Proof of Stake reward. |
| **PoS+RR Side Stake Received** | You received a side stake allocation from another staker's research reward. |
| **PoS Side Stake Sent** | Your Proof of Stake staking reward automatically allocated this side stake to a configured address. **No manual send occurred.** This transaction is normal even when your wallet is locked for staking only. |
| **PoS+RR Side Stake Sent** | Your research staking reward automatically allocated this side stake to a configured address. **No manual send occurred.** This transaction is normal even when your wallet is locked for staking only. |

> **Note:** "Side Stake Sent" transactions are the most common source of user
> confusion. They appear as outgoing transactions, but they are automatically
> created as part of the staking process — the wallet does not need to be fully
> unlocked for them to occur. If you see these transactions and did not configure
> side stakes yourself, check your `gridcoinresearch.conf` for `sidestake=`
> entries, or look in Settings > Options > Staking for configured side stakes.
> Mandatory network-level side stakes (e.g. the Gridcoin foundation address) are
> applied automatically to all stakers.

## MRC (Manual Rewards Claim)

MRC allows researchers who are not actively staking to claim their accrued BOINC
research rewards. The researcher submits an MRC request, and the next staker
includes it in their block, paying the researcher from the coinbase.

| Label | Description |
|-------|-------------|
| **Manual Rewards Claim Request** | You submitted an MRC request to claim your accrued research rewards. This is a user-initiated transaction. |
| **MRC Payment Received** | You received a research reward payment because a staker included your MRC claim in their block. |
| **MRC Payment Sent** | Your staked block automatically paid an MRC claim to a researcher. **No manual send occurred.** This transaction is normal even when your wallet is locked for staking only. |

> **Note:** Like "Side Stake Sent," "MRC Payment Sent" can appear as an outgoing
> transaction from a locked wallet. This is expected behavior — when your wallet
> stakes a block that contains pending MRC claims, it automatically pays those
> claims as part of the block reward distribution.

## Contract Transactions

These transactions record on-chain governance and identity actions.

| Label | Description |
|-------|-------------|
| **Beacon Advertisement** | A transaction that advertises or renews your beacon, linking your BOINC CPID to your wallet address for research reward eligibility. |
| **Poll** | A transaction that creates an on-chain governance poll. |
| **Vote** | A transaction that records your vote on an on-chain poll. |
| **Message** | A transaction that records an on-chain message. |

## Other

| Label | Description |
|-------|-------------|
| *(unlabeled)* | A transaction with mixed inputs and outputs that could not be broken down into individual payees. This is uncommon in normal wallet usage. |
