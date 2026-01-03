# Gridcoin Common Tasks Guide

## Practical How-To Reference

This guide provides step-by-step workflows for common development scenarios in the Gridcoin codebase. Follow Baby Steps™ methodology - tackle one focused change at a time.

---

## Table of Contents

1. [Adding a New RPC Command](#1-adding-a-new-rpc-command)
2. [Adding a New Contract Type](#2-adding-a-new-contract-type)
3. [Modifying Consensus Rules](#3-modifying-consensus-rules)
4. [Adding GUI Features](#4-adding-gui-features)
5. [Debugging Research Reward Issues](#5-debugging-research-reward-issues)
6. [Working with the Test Suite](#6-working-with-the-test-suite)
7. [Investigating Blockchain Issues](#7-investigating-blockchain-issues)
8. [Modifying Scraper Logic](#8-modifying-scraper-logic)
9. [Protocol Parameter Changes](#9-protocol-parameter-changes)
10. [Performance Optimization](#10-performance-optimization)
11. [Ensuring Documentation Passes Lint Checks](#11-ensuring-documentation-passes-lint-checks)

---

## 1. Adding a New RPC Command

### Scenario
You want to add a new RPC command for users to query or modify wallet/blockchain state.

### Steps

#### 1.1 Choose the Appropriate File
Determine which category your command belongs to:
- **Blockchain queries**: `src/rpc/blockchain.cpp`
- **Wallet operations**: `src/rpc/wallet.cpp`
- **Network info**: `src/rpc/net.cpp`
- **Research/BOINC**: `src/rpc/researcher.cpp`
- **Staking**: `src/rpc/mining.cpp`
- **Contracts**: `src/rpc/contract.cpp`

#### 1.2 Implement the Command Function
```cpp
// Example: src/rpc/researcher.cpp

UniValue mycommand(const JSONRPCRequest& request)
{
    // 1. Define help text
    if (request.fHelp || request.params.size() != 1) {
        throw std::runtime_error(
            "mycommand \"param\"\n"
            "\nDescription of what the command does.\n"
            "\nArguments:\n"
            "1. param    (string, required) Description of parameter\n"
            "\nResult:\n"
            "{\n"
            "  \"result\": \"value\"    (string) Description of result\n"
            "}\n"
            "\nExamples:\n"
            + HelpExampleCli("mycommand", "\"example_value\"")
            + HelpExampleRpc("mycommand", "\"example_value\"")
        );
    }

    // 2. Parse parameters
    std::string param = request.params[0].get_str();

    // 3. Acquire locks if needed
    LOCK(cs_main);  // For blockchain state
    // LOCK2(cs_main, pwalletMain->cs_wallet);  // For wallet state

    // 4. Perform operation
    std::string result = PerformOperation(param);

    // 5. Build JSON response
    UniValue response(UniValue::VOBJ);
    response.pushKV("result", result);

    return response;
}
```

#### 1.3 Register the Command
In the same file, add to the `CRPCCommand` array:
```cpp
static const CRPCCommand commands[] = {
    // ... existing commands ...
    { "category", "mycommand", &mycommand, {"param"} },
};
```

Categories: `"blockchain"`, `"wallet"`, `"network"`, `"mining"`, `"research"`, `"contract"`, `"util"`

#### 1.4 Test the Command
```bash
# Start the wallet in testnet mode
./gridcoinresearchd -testnet -daemon

# Test the command
./gridcoinresearch-cli -testnet mycommand "test_value"

# Check debug.log for errors
tail -f ~/.GridcoinResearch/testnet/debug.log
```

#### 1.5 Add Documentation
Update relevant documentation:
- Add to `src/rpc/server.h` if it needs external declaration
- Document in user guides if public-facing

### Common Patterns

**Reading Blockchain State**:
```cpp
LOCK(cs_main);
CBlockIndex* pindex = chainActive.Tip();
int height = pindex->nHeight;
```

**Reading Researcher Context**:
```cpp
auto researcher = GRC::Researcher::Get();
if (researcher->Id().Which() == GRC::MiningId::Kind::CPID) {
    GRC::Cpid cpid = researcher->Id().TryCpid().value();
}
```

**Querying Registries**:
```cpp
auto beacon = GetBeaconRegistry().Try(cpid);
if (beacon) {
    // Use beacon
}
```

---

## 2. Adding a New Contract Type

### Scenario
You need to add a new type of blockchain contract for governance or state management.

### Steps

#### 2.1 Define the Contract Type
Edit `src/gridcoin/contract/contract.h`:
```cpp
enum class ContractType : uint32_t {
    UNKNOWN,
    BEACON,
    // ... existing types ...
    MYNEWTYPE,  // Add your type
};
```

Update the type mapping functions in `src/gridcoin/contract/contract.cpp`:
```cpp
ContractType ContractType::Parse(std::string input) {
    // ... existing mappings ...
    if (input == "mynewtype") return ContractType::MYNEWTYPE;
    return ContractType::UNKNOWN;
}

std::string ContractType::ToString(ContractType type) {
    // ... existing cases ...
    case ContractType::MYNEWTYPE: return "mynewtype";
    default: return "unknown";
}
```

#### 2.2 Create the Payload Class
Create `src/gridcoin/mynewtype.h`:
```cpp
namespace GRC {

// Entry structure (what gets stored)
class MyNewTypeEntry {
public:
    std::string m_key;
    std::string m_value;
    int64_t m_timestamp;
    uint256 m_hash;

    // Status tracking
    enum class Status { ACTIVE, DELETED, PENDING };
    Status m_status;

    // Required methods
    bool WellFormed() const;
    std::string Key() const { return m_key; }
    std::pair<std::string, std::string> KeyValueToString() const;

    // Serialization
    ADD_SERIALIZE_METHODS;
    template <typename Stream, typename Operation>
    inline void SerializationOp(Stream& s, Operation ser_action) {
        READWRITE(m_key);
        READWRITE(m_value);
        READWRITE(m_timestamp);
        READWRITE(m_hash);
    }
};

// Contract payload (what goes in transactions)
class MyNewTypePayload : public IContractPayload {
public:
    MyNewTypeEntry m_entry;

    // IContractPayload interface
    GRC::ContractType ContractType() const override {
        return GRC::ContractType::MYNEWTYPE;
    }

    bool WellFormed(const ContractAction action) const override {
        return m_entry.WellFormed();
    }

    std::string LegacyKeyString() const override {
        return m_entry.Key();
    }

    std::string LegacyValueString() const override {
        return m_entry.m_value;
    }

    CAmount RequiredBurnAmount() const override {
        return 0.5 * COIN;  // Set appropriate burn fee
    }

    ADD_SERIALIZE_METHODS;
    template <typename Stream, typename Operation>
    inline void SerializationOp(Stream& s, Operation ser_action) {
        READWRITE(m_entry);
    }
};

// Registry (handler and state manager)
class MyNewTypeRegistry : public IContractHandler {
private:
    // Storage maps
    std::map<std::string, std::shared_ptr<MyNewTypeEntry>> m_entries;

public:
    // IContractHandler interface
    void Reset() override;
    bool Validate(const Contract& contract, const CTransaction& tx, int& DoS) const override;
    bool BlockValidate(const ContractContext& ctx, int& DoS) const override;
    void Add(const ContractContext& ctx) override;
    void Delete(const ContractContext& ctx) override;
    void Revert(const ContractContext& ctx) override;

    // Custom query methods
    std::shared_ptr<MyNewTypeEntry> Try(const std::string& key) const;
};

MyNewTypeRegistry& GetMyNewTypeRegistry();

} // namespace GRC
```

#### 2.3 Implement the Registry
Create `src/gridcoin/mynewtype.cpp`:
```cpp
#include "gridcoin/mynewtype.h"
#include "main.h"  // For cs_main

using namespace GRC;

namespace {
MyNewTypeRegistry g_registry;
}

MyNewTypeRegistry& GRC::GetMyNewTypeRegistry() {
    return g_registry;
}

bool MyNewTypeEntry::WellFormed() const {
    return !m_key.empty() && !m_value.empty();
}

bool MyNewTypeRegistry::Validate(const Contract& contract, const CTransaction& tx, int& DoS) const {
    const auto payload = contract.SharePayload<MyNewTypePayload>();

    if (!payload->WellFormed(contract.m_action)) {
        DoS = 25;
        return false;
    }

    // Additional validation logic
    return true;
}

void MyNewTypeRegistry::Add(const ContractContext& ctx) {
    const auto payload = ctx.m_contract.SharePayload<MyNewTypePayload>();
    auto entry = std::make_shared<MyNewTypeEntry>(payload->m_entry);
    entry->m_status = MyNewTypeEntry::Status::ACTIVE;
    entry->m_timestamp = ctx.m_pindex->nTime;

    m_entries[entry->Key()] = entry;
}

// Implement other methods...
```

#### 2.4 Register with Dispatcher
Edit `src/gridcoin/contract/contract.cpp`:
```cpp
IContractHandler& Dispatcher::GetHandler(const ContractType type) {
    switch (type) {
        // ... existing cases ...
        case ContractType::MYNEWTYPE:
            return GetMyNewTypeRegistry();
        default:
            return s_unknown_handler;
    }
}
```

#### 2.5 Add to Build System
Edit `src/CMakeLists.txt` or `src/Makefile.am`:
```cmake
# CMakeLists.txt
set(GRIDCOIN_SOURCES
    # ... existing files ...
    gridcoin/mynewtype.cpp
)
```

#### 2.6 Create RPC Commands
Add commands in `src/rpc/contract.cpp` or create new file for managing your contract type.

#### 2.7 Add Tests
Create `src/test/gridcoin/mynewtype_tests.cpp`:
```cpp
#include <boost/test/unit_test.hpp>
#include "gridcoin/mynewtype.h"

BOOST_AUTO_TEST_SUITE(mynewtype_tests)

BOOST_AUTO_TEST_CASE(it_validates_well_formed_entries)
{
    GRC::MyNewTypeEntry entry;
    entry.m_key = "test";
    entry.m_value = "value";

    BOOST_CHECK(entry.WellFormed() == true);
}

BOOST_AUTO_TEST_SUITE_END()
```

---

## 3. Modifying Consensus Rules

### Scenario
You need to change block validation, reward calculation, or other consensus-critical logic.

### ⚠️ WARNING
Consensus changes require:
- **Hard fork coordination**: All nodes must upgrade
- **Activation height**: Rules activate at specific block
- **Extensive testing**: Errors can fork the network
- **Community approval**: Major changes need governance

### Steps

#### 3.1 Identify the Change Location
Common consensus locations:
- **Block validation**: `src/main.cpp` → `CheckBlock()`, `AcceptBlock()`
- **Transaction validation**: `src/main.cpp` → `CheckTransaction()`
- **Reward calculation**: `src/miner.cpp` → Reward functions
- **Difficulty adjustment**: `src/main.cpp` → `GetNextTargetRequired()`

#### 3.2 Add Version/Height Gating
Always gate consensus changes by block height or version:
```cpp
// Example: New rule activating at height 3000000
bool NewConsensusRule(const CBlockIndex* pindex) {
    const int ACTIVATION_HEIGHT = 3000000;
    return pindex->nHeight >= ACTIVATION_HEIGHT;
}

// In validation function
bool ValidateBlock(const CBlock& block, const CBlockIndex* pindex) {
    // Existing validation
    if (!ExistingRule(block)) {
        return false;
    }

    // New rule (only after activation)
    if (NewConsensusRule(pindex)) {
        if (!NewRule(block)) {
            return error("Block fails new consensus rule");
        }
    }

    return true;
}
```

#### 3.3 Update Block Version If Needed
If adding substantial changes:
```cpp
// src/primitives/block.h
static const int32_t CURRENT_VERSION = 12;  // Increment

// src/main.cpp - Check version
if (block.nVersion < MINIMUM_VERSION) {
    return state.DoS(100, error("version too old"));
}
```

#### 3.4 Test on Testnet First
```bash
# Build with testnet
cmake --build . --target gridcoinresearchd

# Run testnet node
./gridcoinresearchd -testnet -daemon

# Monitor for issues
tail -f ~/.GridcoinResearch/testnet/debug.log
```

#### 3.5 Document the Fork
Update:
- `CHANGELOG.md`: Document the change
- `doc/release-process.md`: Add to release notes
- Community announcements

### Common Consensus Modifications

**Changing Block Reward**:
```cpp
// src/miner.cpp or wherever reward is calculated
CAmount GetBlockSubsidy(int nHeight) {
    if (nHeight < FORK_HEIGHT) {
        return OLD_REWARD;
    }
    return NEW_REWARD;
}
```

**Adding New Validation**:
```cpp
// src/main.cpp in block validation
if (pindex->nHeight >= NEW_RULE_HEIGHT) {
    if (!ValidateNewRule(block, pindex)) {
        return state.DoS(100, error("new rule violation"));
    }
}
```

---

## 4. Adding GUI Features

### Scenario
You want to add a new dialog, widget, or feature to the Qt GUI.

### Steps

#### 4.1 Create the Dialog Class
Create `src/qt/mynewdialog.h`:
```cpp
#ifndef MYNEWDIALOG_H
#define MYNEWDIALOG_H

#include <QDialog>

namespace Ui {
class MyNewDialog;
}

class WalletModel;

class MyNewDialog : public QDialog
{
    Q_OBJECT

public:
    explicit MyNewDialog(QWidget *parent = nullptr);
    ~MyNewDialog();

    void setModel(WalletModel *model);

private Q_SLOTS:
    void onButtonClicked();
    void updateDisplay();

private:
    Ui::MyNewDialog *ui;
    WalletModel *m_model;
};

#endif
```

#### 4.2 Create the UI File
Create `src/qt/forms/mynewdialog.ui` using Qt Designer or manually:
```xml
<?xml version="1.0" encoding="UTF-8"?>
<ui version="4.0">
 <class>MyNewDialog</class>
 <widget class="QDialog" name="MyNewDialog">
  <property name="geometry">
   <rect><x>0</x><y>0</y><width>400</width><height>300</height></rect>
  </property>
  <property name="windowTitle">
   <string>My New Feature</string>
  </property>
  <layout class="QVBoxLayout">
   <item>
    <widget class="QLabel" name="label">
     <property name="text">
      <string>Feature Description</string>
     </property>
    </widget>
   </item>
   <item>
    <widget class="QPushButton" name="actionButton">
     <property name="text">
      <string>Perform Action</string>
     </property>
    </widget>
   </item>
  </layout>
 </widget>
</ui>
```

#### 4.3 Implement the Dialog
Create `src/qt/mynewdialog.cpp`:
```cpp
#include "mynewdialog.h"
#include "ui_mynewdialog.h"
#include "walletmodel.h"

MyNewDialog::MyNewDialog(QWidget *parent) :
    QDialog(parent),
    ui(new Ui::MyNewDialog),
    m_model(nullptr)
{
    ui->setupUi(this);

    // Connect signals
    connect(ui->actionButton, &QPushButton::clicked,
            this, &MyNewDialog::onButtonClicked);
}

MyNewDialog::~MyNewDialog()
{
    delete ui;
}

void MyNewDialog::setModel(WalletModel *model)
{
    m_model = model;
    updateDisplay();
}

void MyNewDialog::onButtonClicked()
{
    if (!m_model) return;

    // Perform action using model
    // m_model->someOperation();

    updateDisplay();
}

void MyNewDialog::updateDisplay()
{
    // Update UI elements
}
```

#### 4.4 Add to Main Window
Edit `src/qt/bitcoingui.cpp`:
```cpp
// Include header
#include "mynewdialog.h"

// In constructor, add menu action
QAction *myNewAction = new QAction(tr("My New Feature"), this);
myNewAction->setStatusTip(tr("Open my new feature dialog"));
connect(myNewAction, &QAction::triggered, this, &BitcoinGUI::showMyNewDialog);
someMenu->addAction(myNewAction);

// Add slot method
void BitcoinGUI::showMyNewDialog()
{
    if (!walletFrame) return;
    MyNewDialog dialog(this);
    dialog.setModel(walletFrame->currentWalletModel());
    dialog.exec();
}
```

#### 4.5 Register with Build System
Edit `src/qt/CMakeLists.txt` or `src/Makefile.qt.include`:
```cmake
set(QT_FORMS_UI
    # ... existing forms ...
    forms/mynewdialog.ui
)

set(QT_MOC_CPP
    # ... existing mocs ...
    moc_mynewdialog.cpp
)
```

#### 4.6 Test the GUI
```bash
cmake --build . --target gridcoinresearch-qt
./gridcoinresearch-qt -testnet
```

---

## 5. Debugging Research Reward Issues

### Scenario
A user reports incorrect research rewards, zero magnitude, or beacon problems.

### Diagnostic Steps

#### 5.1 Check Researcher Status
```bash
# RPC command
./gridcoinresearch-cli getstakinginfo

# Look for:
# - "researcher_status": Should be "active"
# - "cpid": Should be valid hex string
# - "magnitude": Should be > 0 if doing research
```

#### 5.2 Verify Beacon Status
```bash
./gridcoinresearch-cli beaconstatus

# Check:
# - Beacon age (should be < 6 months)
# - Status (should be "active")
# - Public key matches wallet
```

#### 5.3 Check BOINC Detection
```bash
./gridcoinresearch-cli listprojects

# Verify:
# - Projects are detected
# - Team is correct (Gridcoin)
# - CPID matches
```

#### 5.4 Examine Current Superblock
```bash
# Get current superblock
./gridcoinresearch-cli superblocks

# Check specific CPID magnitude
./gridcoinresearch-cli magnitude <cpid>
```

#### 5.5 Check Accrual
```bash
./gridcoinresearch-cli getaccrual <cpid>

# Returns pending research rewards
```

#### 5.6 Debug Logging
Enable verbose logging:
```bash
# Add to gridcoinresearch.conf
debug=contract
debug=scraper
debug=miner
debug=tally

# Restart and monitor
tail -f ~/.GridcoinResearch/debug.log | grep -i "beacon\|magnitude\|accrual"
```

### Common Issues

**Zero Magnitude**:
1. Check if CPID is in current superblock
2. Verify RAC is being reported by projects
3. Check if project is greylisted
4. Ensure beacon is active

**Beacon Not Activating**:
1. Wait for next superblock (up to 24 hours)
2. Verify beacon transaction confirmed
3. Check beacon appears in pending list

**Accrual Not Increasing**:
1. Verify magnitude > 0
2. Check superblock is being updated
3. Ensure beacon hasn't expired

---

## 6. Working with the Test Suite

### Scenario
You need to add tests or debug failing tests.

### Running Tests

```bash
# Build tests
cmake --build . --target test_gridcoinresearch

# Run all tests
./src/test/test_gridcoinresearch

# Run specific test suite
./src/test/test_gridcoinresearch --run_test=beacon_tests

# Run with verbose output
./src/test/test_gridcoinresearch --log_level=all
```

### Writing Unit Tests

Create `src/test/gridcoin/myfeature_tests.cpp`:
```cpp
#include <boost/test/unit_test.hpp>
#include "gridcoin/myfeature.h"

BOOST_AUTO_TEST_SUITE(myfeature_tests)

BOOST_AUTO_TEST_CASE(it_does_something_correctly)
{
    // Arrange
    GRC::MyFeature feature;

    // Act
    bool result = feature.DoSomething();

    // Assert
    BOOST_CHECK(result == true);
}

BOOST_AUTO_TEST_CASE(it_handles_errors_gracefully)
{
    GRC::MyFeature feature;

    // Test error condition
    BOOST_CHECK_THROW(feature.DoInvalidOperation(), std::runtime_error);
}

BOOST_AUTO_TEST_SUITE_END()
```

### Test Fixtures
For tests requiring blockchain state:
```cpp
#include "test/test_gridcoin.h"  // Provides TestChain100Setup

BOOST_FIXTURE_TEST_SUITE(myfeature_tests, TestChain100Setup)

BOOST_AUTO_TEST_CASE(it_works_with_blockchain)
{
    // You have a 100-block chain available
    BOOST_CHECK(chainActive.Height() == 100);

    // Test code
}

BOOST_AUTO_TEST_SUITE_END()
```

---

## 7. Investigating Blockchain Issues

### Scenario
Node is stuck, forked, or showing unexpected behavior.

### Diagnostic Commands

```bash
# Check sync status
./gridcoinresearch-cli getblockchaininfo

# Get current best block
./gridcoinresearch-cli getbestblockhash

# Check specific block
./gridcoinresearch-cli getblock <hash>

# View mempool
./gridcoinresearch-cli getrawmempool

# Check peers
./gridcoinresearch-cli getpeerinfo

# Examine connections
./gridcoinresearch-cli getnetworkinfo
```

### Common Fixes

**Node Stuck Syncing**:
```bash
# Restart with fresh peers
./gridcoinresearch-cli stop
rm ~/.GridcoinResearch/peers.dat
./gridcoinresearchd -daemon
```

**Potential Fork**:
```bash
# Compare block hash with explorer
./gridcoinresearch-cli getblockhash <height>

# If forked, may need to resync
./gridcoinresearch-cli stop
# Backup wallet first!
rm -rf ~/.GridcoinResearch/blocks ~/.GridcoinResearch/chainstate
./gridcoinresearchd -daemon
```

**Debug Validation Failures**:
```bash
# Enable verbose validation logging
./gridcoinresearchd -debug=validation -printtoconsole
```

---

## 8. Modifying Scraper Logic

### Scenario
You need to change how statistics are collected or processed.

### Key Files
- `src/scraper/scraper.cpp`: Main scraper logic
- `src/scraper/http.cpp`: HTTP downloading
- `src/gridcoin/quorum.cpp`: Convergence algorithm

### Example: Adding Project Validation

Edit `src/scraper/scraper.cpp`:
```cpp
bool ValidateProjectStats(const ProjectStats& stats) {
    // Add custom validation
    if (stats.total_rac < 0) {
        LogPrintf("ERROR: Negative RAC detected");
        return false;
    }

    // Existing validation
    return true;
}
```

### Testing Scraper Changes

```bash
# Run as active scraper
./gridcoinresearchd -scraper -debug=scraper

# Monitor scraper activity
tail -f ~/.GridcoinResearch/debug.log | grep -i scraper

# Check manifest generation
./gridcoinresearch-cli getscrapermanifest
```

---

## 9. Protocol Parameter Changes

### Scenario
Need to modify protocol parameters (stake age, superblock interval, etc.)

### Via Protocol Contract (Runtime)

1. Create protocol entry contract
2. Broadcast to network
3. Parameters update when activated

### Via Code (Hard Fork)

Edit consensus parameters:
```cpp
// src/gridcoin/quorum.cpp
int64_t GetSuperblockInterval() {
    if (nBestHeight >= FORK_HEIGHT) {
        return NEW_INTERVAL;
    }
    return OLD_INTERVAL;
}
```

---

## 10. Performance Optimization

### Profiling

```bash
# Build with profiling
cmake -DCMAKE_BUILD_TYPE=RelWithDebInfo ..
cmake --build .

# Run with profiler
valgrind --tool=callgrind ./gridcoinresearchd

# Analyze
kcachegrind callgrind.out.*
```

### Common Optimizations

**Reduce Lock Contention**:
```cpp
// Move expensive work outside locks
std::vector<Data> data;
{
    LOCK(cs_registry);
    data = registry.GetData();  // Quick copy
}
// Process data without lock
ProcessData(data);
```

**Cache Expensive Queries**:
```cpp
mutable std::optional<CachedResult> m_cache;

Result GetResult() const {
    if (!m_cache) {
        m_cache = ExpensiveCalculation();
    }
    return *m_cache;
}
```

**Use Const References**:
```cpp
// Avoid copies
void ProcessData(const LargeObject& obj) {  // Reference
    // Use obj
}
```

---

## 11. Ensuring Documentation Passes Lint Checks

### Scenario
You've created or modified markdown documentation and need to ensure it passes the project's lint checker before submitting to GitHub.

### Understanding Lint Requirements
The Gridcoin project uses `test/lint/lint-whitespace.sh` which checks:
- **Trailing whitespace** at end of lines
- **Tab characters** instead of spaces (in code files)
- Various other whitespace issues

Lint failures will **block PR merges** in GitHub CI/CD, so it's essential to verify before committing.

### Quick Fix for Markdown Files

Remove trailing whitespace from all markdown files in a directory:
```bash
cd path/to/directory
for file in *.md; do sed -i 's/[[:space:]]*$//' "$file"; done
```

Verify the fix worked:
```bash
# Should return nothing if all whitespace is removed
grep -n '\s\+$' *.md
```

### Running Full Lint Suite

From repository root:
```bash
# Run all lint checks
test/lint/lint-all.sh

# Run only whitespace check
test/lint/lint-whitespace.sh
```

### Common Issues

**VS Code "Trim Trailing Whitespace" Not Working**:
- May only apply to current file, not all files
- Use the sed command above for comprehensive cleanup

**Mixed Line Endings** (Windows):
```bash
# Convert CRLF to LF
dos2unix *.md
# Or
sed -i 's/\r$//' *.md
```

**Tab Characters in Markdown**:
```bash
# Find tabs
grep -n $'\t' *.md

# Replace tabs with 4 spaces
sed -i 's/\t/    /g' *.md
```

### Pre-Commit Checklist
- [ ] No trailing whitespace
- [ ] No tab characters in markdown
- [ ] Code examples use consistent indentation
- [ ] Lint checker passes (`test/lint/lint-all.sh`)

**Remember**: Always verify lint compliance before submitting documentation PRs to avoid CI failures.

---

## General Development Tips

### Baby Steps™ Checklist
- [ ] Make one focused change
- [ ] Compile and test immediately
- [ ] Document what and why
- [ ] Commit with clear message
- [ ] Validate before moving to next step

### Code Review Checklist
- [ ] Follows coding style (`01-coding.md`)
- [ ] Proper lock ordering
- [ ] No consensus changes without hard fork planning
- [ ] Added tests for new features
- [ ] Updated documentation
- [ ] Considered backward compatibility

### Debugging Tools
- **Debug logging**: `-debug=<category>` flag
- **Print to console**: `-printtoconsole` flag
- **GDB**: `gdb ./gridcoinresearchd`
- **Valgrind**: Memory leak detection
- **Address sanitizer**: `-fsanitize=address` compile flag

---

## Related Documentation

- **Architecture**: `02-architecture-overview.md`
- **Glossary**: `03-core-concepts-glossary.md`
- **Components**: `04-component-guide.md`
- **Coding Style**: `01-coding.md`

This guide provides practical workflows for common tasks. Always take Baby Steps™ - make one focused change at a time, test thoroughly, and document your work. **The process is the product.**
