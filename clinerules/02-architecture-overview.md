# Gridcoin Architecture Overview

## System Architecture

Gridcoin is a Bitcoin-derived proof-of-stake cryptocurrency with integrated research reward mechanisms. The architecture can be understood in several interconnected layers:

```
┌─────────────────────────────────────────────────────────────────┐
│                     USER INTERFACE LAYER                         │
│  Qt GUI (src/qt/) | RPC API (src/rpc/) | CLI (gridcoinresearchd) │
└─────────────────────────────────────────────────────────────────┘
                              ↓
┌─────────────────────────────────────────────────────────────────┐
│                   APPLICATION LOGIC LAYER                        │
│  Wallet | Miner/Staker | Researcher Context | Backup/Upgrade     │
└─────────────────────────────────────────────────────────────────┘
                              ↓
┌─────────────────────────────────────────────────────────────────┐
│                  GRIDCOIN BUSINESS LOGIC LAYER                   │
│  Contract System | Research Accounting | Consensus (Quorum)      │
│  Beacon Registry | Project Whitelist | Superblock Management    │
└─────────────────────────────────────────────────────────────────┘
                              ↓
┌─────────────────────────────────────────────────────────────────┐
│                   BLOCKCHAIN CONSENSUS LAYER                     │
│  Block Validation | Transaction Processing | Proof-of-Stake      │
│  Chain Management | Checkpoint System                            │
└─────────────────────────────────────────────────────────────────┘
                              ↓
┌─────────────────────────────────────────────────────────────────┐
│                    NETWORK & STORAGE LAYER                       │
│  P2P Networking (src/net.*) | LevelDB | Wallet DB | Scraper     │
│  BOINC Integration | Address Management | Backup System          │
└─────────────────────────────────────────────────────────────────┘
```

## Core Architectural Components

### 1. Contract System (`src/gridcoin/contract/`)
The contract system is Gridcoin's mechanism for blockchain-based governance and configuration changes.

**Key Concepts:**
- **Contracts** are special transactions that modify blockchain state
- **Contract Types**: Beacon, Project (whitelist), Protocol, SideStake, MRC, TxMessage
- **Contract Actions**: Add, Delete, Remove
- **Handlers** process and validate contracts (registry pattern)
- **Registries** maintain current state for each contract type

**Data Flow:**
```
Transaction → Contract Detection → Validation → Handler Dispatch → Registry Update
                                        ↓
                              (Burn Fee Verification)
```

### 2. Research Reward System (`src/gridcoin/`)

**Components:**
- **Beacon Registry** (`beacon.h/cpp`): Maps CPIDs to public keys for reward claims
- **Researcher Context** (`researcher.h/cpp`): Tracks local BOINC projects and eligibility
- **Tally System** (`tally.h/cpp`): Calculates research reward accruals
- **Magnitude** (`magnitude.h`): Measures relative research contribution (0-32767 scale)

**Reward Flow:**
```
BOINC Stats → Scraper Collection → Superblock Consensus →
Magnitude Assignment → Accrual Calculation → Stake Block Claim
```

### 3. Superblock & Quorum System (`src/gridcoin/quorum.*, superblock.*`)

**Purpose:** Achieve distributed consensus on research statistics without central authority.

**Process:**
1. **Scraper Nodes** collect BOINC project statistics independently
2. **Convergence** algorithm finds agreement among scraper manifests
3. **Superblock** created containing project stats and CPID magnitudes
4. **Quorum** validation ensures supermajority agreement
5. **Committed** to blockchain approximately every 24 hours

**Validation Hierarchy:**
```
Raw Stats → Manifest Creation → Convergence Analysis →
Superblock Generation → Quorum Validation → Blockchain Commitment
```

### 4. Proof-of-Stake Consensus (`src/miner.*, main.cpp`)

**Key Differences from Bitcoin:**
- **No mining**: Uses coin-age based staking instead of proof-of-work
- **Research Rewards**: Stake blocks claim accumulated research rewards
- **Dual Subsidy**: Block reward = stake subsidy + research subsidy
- **Required Elements**: Kernel meets difficulty target, valid coinstake transaction

**Staking Process:**
```
UTXO Selection → Kernel Hash Calculation → Difficulty Check →
Coinstake Creation → Research Claim (if applicable) → Block Assembly → Broadcast
```

### 5. Accrual Accounting System (`src/gridcoin/tally.*`)

**Purpose:** Track research rewards earned but not yet claimed.

**Modes:**
- **Snapshot Mode** (current): Fast accrual calculation using periodic snapshots
- **Legacy Mode** (pre-v5): Full blockchain scan for each calculation

**Key Operations:**
- `RecordRewardBlock()`: Mark when CPID claims rewards
- `GetAccrual()`: Calculate pending rewards for a CPID
- `ApplySuperblock()`: Update magnitude assignments
- `TallyMagnitudeAverages()`: Maintain historical averages

### 6. Scraper System (`src/scraper/`)

**Function:** Distributed statistics collection from BOINC projects.

**Components:**
- **Scraper**: Downloads and parses project statistics files
- **Convergence**: Finds agreement among multiple scrapers
- **Manifest**: Signed package of collected statistics
- **Project Parts**: Individual project data with hash verification

**Redundancy:** Multiple independent scrapers ensure no single point of failure.

## Data Persistence

### Databases
- **Blockchain** (`blk*.dat`, `rev*.dat`): Block and undo data
- **LevelDB** (`blocks/index/`): Block index, transaction index
- **Wallet** (`wallet.dat`): Keys, transactions, metadata
- **Registry DBs**: Beacon, project, protocol, sidestake state

### Configuration
- **gridcoinresearch.conf**: User settings
- **config.xml** (BOINC): Client state for researcher detection

## Thread Architecture

Key threads (see `01-coding.md` for complete list):
- **grc-appinit2**: Main initialization
- **grc-net**: P2P networking
- **grc-msghand**: Message processing
- **grc-stake-miner**: Block staking
- **grc-scraper**: Statistics collection (alternative to subscriber)
- **grc-scraper-subscriber**: Receive manifests from other scrapers

## Critical Synchronization

**Locks:**
- `cs_main`: Blockchain state (most critical)
- `cs_wallet`: Wallet operations
- `pwalletMain->cs_wallet`: Wallet instance lock
- Registry-specific locks for contract state

**Lock Order:** Generally `cs_main` → `cs_wallet` to prevent deadlocks.

## Upgrade & Compatibility

**Version Transitions:**
- **Hard Forks**: Require blockchain-wide upgrade at specific height
- **Protocol Bumps**: Change P2P message format or validation rules
- **Soft Changes**: Backward compatible improvements

**Block Versions:**
- Version 11: Current consensus rules
- Version 10: Legacy superblock format
- Earlier versions: Phased out

## External Integrations

### BOINC
- **Detection**: Parse `client_state.xml` for projects and CPIDs
- **Statistics**: Scraper downloads from project stat export URLs
- **No Direct Communication**: Gridcoin reads BOINC state passively

### Network Services
- **Snapshot Server**: Fast blockchain sync (`snapshot.gridcoin.us`)
- **Update Checker**: Version notification system
- **DNS Seeders**: Bootstrap peer discovery

## Security Considerations

1. **Beacon Security**: Private key proves CPID ownership for reward claims
2. **Superblock Validation**: Multi-scraper consensus prevents manipulation
3. **Contract Burns**: Prevent spam by requiring burned coins
4. **Mandatory Sidestakes**: Protocol-enforced fee distributions
5. **Split CPID Detection**: Prevents gaming by using same email across projects

## Performance Characteristics

- **Block Time**: ~90 seconds target
- **Superblock Interval**: ~1 day (daily consensus on magnitudes)
- **Beacon Lifetime**: ~6 months before renewal required
- **Accrual Limit**: ~16,384 GRC maximum unclaimed research rewards
- **Stake Weight**: Calculated from coin age and UTXO amount

## Future Architecture Notes

**Modular Design Goals:**
- Cleaner separation between consensus and business logic
- More testable components with dependency injection
- Reduced global state and lock contention
- Better abstraction of blockchain storage

This architecture has evolved from Bitcoin's original design while adding substantial complexity for research reward integration. Understanding the contract system, superblock consensus, and accrual accounting is essential for working with Gridcoin-specific features.
