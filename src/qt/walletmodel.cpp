#include "walletmodel.h"
#include "guiconstants.h"
#include "optionsmodel.h"
#include "addresstablemodel.h"
#include "transactiontablemodel.h"

#include "node/ui_interface.h"
#include "wallet/wallet.h"
#include <key_io.h>
#include "util.h"
#include "gridcoin/tx_message.h"

#include <QSet>
#include <QTimer>

void qtInsertConfirm(double dAmt, std::string sFrom, std::string sTo, std::string txid);

WalletModel::WalletModel(CWallet* wallet, OptionsModel* optionsModel, QObject* parent)
         : QObject(parent)
         , wallet(wallet)
         , optionsModel(optionsModel)
         , addressTableModel(nullptr)
         , transactionTableModel(nullptr)
         , cachedBalance(0)
         , cachedStake(0)
         , cachedUnconfirmedBalance(0)
         , cachedImmatureBalance(0)
         , cachedNumTransactions(0)
         , cachedEncryptionStatus(Unencrypted)
         , cachedNumBlocks(0)
{
    addressTableModel = new AddressTableModel(wallet, this);
    transactionTableModel = new TransactionTableModel(wallet, this);

    // This timer will be fired repeatedly to update the balance
    pollTimer = new QTimer(this);
    connect(pollTimer, &QTimer::timeout, this, &WalletModel::pollBalanceChanged);
    pollTimer->start(MODEL_UPDATE_DELAY);

    subscribeToCoreSignals();
}

WalletModel::~WalletModel()
{
    unsubscribeFromCoreSignals();
}

qint64 WalletModel::getBalance() const
{
    return wallet->GetBalance();
}

qint64 WalletModel::getUnconfirmedBalance() const
{
    return wallet->GetUnconfirmedBalance();
}

qint64 WalletModel::getStake() const
{
    return wallet->GetStake();
}

qint64 WalletModel::getImmatureBalance() const
{
    return wallet->GetImmatureBalance();
}

int WalletModel::getNumTransactions() const
{
    int numTransactions = 0;
    {
        LOCK(wallet->cs_wallet);
        numTransactions = wallet->mapWallet.size();
    }
    return numTransactions;
}

void WalletModel::updateStatus()
{
    EncryptionStatus newEncryptionStatus = getEncryptionStatus();

    if(cachedEncryptionStatus != newEncryptionStatus)
        emit encryptionStatusChanged(newEncryptionStatus);
}

void WalletModel::pollBalanceChanged()
{
    // Get required locks upfront. This avoids the GUI from getting stuck on
    // periodical polls if the core is holding the locks for a longer time -
    // for example, during a wallet rescan.
    TRY_LOCK(cs_main, lockMain);
    if(!lockMain)
        return;
    TRY_LOCK(wallet->cs_wallet, lockWallet);
    if(!lockWallet)
        return;

    if(nBestHeight != cachedNumBlocks)
    {
        // Balance and number of transactions might have changed
        cachedNumBlocks = nBestHeight;

        checkBalanceChanged();
        if(transactionTableModel)
            transactionTableModel->updateConfirmations();
    }
}

void WalletModel::checkBalanceChanged()
{
    // These are INCREDIBLY expensive calls for wallets with a large transaction map size. Use a timed expire (stale)
    // pattern to avoid calling these repeatedly for rapid fire updates which occur during a blockchain resync or
    // rescan of a busy wallet, or a transaction that changes lots of UTXO's statuses, such as consolidateunspent.

    // We don't have to worry about the last call to this being lost (absorbed) because it doesn't pass the stale
    // test, because the balance will be updated anyway by the timer poll in MODEL_UPDATE_DELAY seconds period.
    int64_t current_time = GetAdjustedTime();

    if (current_time - last_balance_update_time > MODEL_UPDATE_DELAY / 1000)
    {
        qint64 newBalance = getBalance();
        qint64 newStake = getStake();
        qint64 newUnconfirmedBalance = getUnconfirmedBalance();
        qint64 newImmatureBalance = getImmatureBalance();

        if (cachedBalance != newBalance
                || cachedStake != newStake
                || cachedUnconfirmedBalance != newUnconfirmedBalance
                || cachedImmatureBalance != newImmatureBalance)
        {
            cachedBalance = newBalance;
            cachedStake = newStake;
            cachedUnconfirmedBalance = newUnconfirmedBalance;
            cachedImmatureBalance = newImmatureBalance;

            last_balance_update_time = current_time;

            emit balanceChanged(newBalance, newStake, newUnconfirmedBalance, newImmatureBalance);
        }
    }
}

void WalletModel::updateTransaction(const QString &hash, int status)
{
    LogPrint(BCLog::MISC, "WalletModel::updateTransaction()");

    if (transactionTableModel)
    {
        transactionTableModel->updateTransaction(hash, status);

        // Note this is subtly different than the below. If a resync is being done on a wallet
        // that already has transactions, the numTransactionsChanged will not be emitted after the
        // wallet is loaded because the size() does not change. See the comments in the header file.
        emit transactionUpdated();
    }

    // Balance and number of transactions might have changed
    checkBalanceChanged();

    int newNumTransactions = getNumTransactions();
    if (cachedNumTransactions != newNumTransactions)
    {
        cachedNumTransactions = newNumTransactions;

        emit numTransactionsChanged(newNumTransactions);
    }
}

void WalletModel::updateAddressBook(const QString &address, const QString &label, bool isMine, int status)
{
    if(addressTableModel)
        addressTableModel->updateEntry(address, label, isMine, status);
}

bool WalletModel::validateAddress(const QString &address)
{
    CTxDestination addressParsed = DecodeDestination(address.toStdString());
    return IsValidDestination(addressParsed);
}

WalletModel::SendCoinsReturn WalletModel::sendCoins(const QList<SendCoinsRecipient> &recipients, const CCoinControl *coinControl)
{
    qint64 total = 0;
    QSet<QString> setAddress;
    QString hex;

    if(recipients.empty())
    {
        return OK;
    }

    // Pre-check input data for validity
    for (const SendCoinsRecipient& rcp : recipients) {
        if(!validateAddress(rcp.address))
        {
            return InvalidAddress;
        }
        setAddress.insert(rcp.address);

        if(rcp.amount <= 0)
        {
            return InvalidAmount;
        }
        total += rcp.amount;
    }

    if(recipients.size() > setAddress.size())
    {
        return DuplicateAddress;
    }

    int64_t nBalance = 0;
    std::vector<COutput> vCoins;
    wallet->AvailableCoins(vCoins, true, coinControl,false);

    for (auto const& out : vCoins)
        nBalance += out.tx->vout[out.i].nValue;

    if(total > nBalance)
    {
        return AmountExceedsBalance;
    }

    if((total + nTransactionFee) > nBalance)
    {
        return SendCoinsReturn(AmountWithFeeExceedsBalance, nTransactionFee);
    }

    CWalletTx wtx;

    if (!recipients[0].Message.isEmpty())
    {
        wtx.vContracts.emplace_back(GRC::MakeContract<GRC::TxMessage>(
            GRC::ContractAction::ADD,
            recipients[0].Message.toStdString()));
    }

    {
        LOCK2(cs_main, wallet->cs_wallet);

        // Sendmany
        std::vector<std::pair<CScript, int64_t> > vecSend;
        for (const SendCoinsRecipient& rcp : recipients) {
            CScript scriptPubKey;
            scriptPubKey.SetDestination(DecodeDestination(rcp.address.toStdString()));
            vecSend.push_back(std::make_pair(scriptPubKey, rcp.amount));
        }

        CReserveKey keyChange(wallet);
        int64_t nFeeRequired = 0;
		bool fCreated = wallet->CreateTransaction(vecSend, wtx, keyChange, nFeeRequired, coinControl);

        if(!fCreated)
        {
            if((total + nFeeRequired) > nBalance) // FIXME: could cause collisions in the future
            {
                return SendCoinsReturn(AmountWithFeeExceedsBalance, nFeeRequired);
            }
            return TransactionCreationFailed;
        }

        if(!uiInterface.ThreadSafeAskFee(nFeeRequired, tr("Sending...").toStdString()))
        {
            return Aborted;
        }
        if(!wallet->CommitTransaction(wtx, keyChange))
        {
            return TransactionCommitFailed;
        }
        hex = QString::fromStdString(wtx.GetHash().GetHex());
    }

    // Add addresses / update labels that we've sent to the address book
    for (const SendCoinsRecipient& rcp : recipients) {
        std::string strAddress = rcp.address.toStdString();
        CTxDestination dest = DecodeDestination(strAddress);
        std::string strLabel = rcp.label.toStdString();
        {
            LOCK(wallet->cs_wallet);

            std::map<CTxDestination, std::string>::iterator mi = wallet->mapAddressBook.find(dest);

            // Check if we have a new address or an updated label
            if (mi == wallet->mapAddressBook.end() || mi->second != strLabel)
            {
                wallet->SetAddressBookName(dest, strLabel);
            }
        }
    }

    return SendCoinsReturn(OK, 0, hex);
}

OptionsModel *WalletModel::getOptionsModel()
{
    return optionsModel;
}

AddressTableModel *WalletModel::getAddressTableModel()
{
    return addressTableModel;
}

TransactionTableModel *WalletModel::getTransactionTableModel()
{
    return transactionTableModel;
}

WalletModel::EncryptionStatus WalletModel::getEncryptionStatus() const
{
    if(!wallet->IsCrypted())
    {
        return Unencrypted;
    }
    else if(wallet->IsLocked())
    {
        return Locked;
    }
    else
    {
        return Unlocked;
    }
}

bool WalletModel::setWalletEncrypted(const SecureString& passphrase)
{
        return wallet->EncryptWallet(passphrase);
}

bool WalletModel::setWalletLocked(bool locked, const SecureString &passPhrase)
{
    if(locked)
    {
        // Lock
        return wallet->Lock();
    }
    else
    {
        // Unlock
        return wallet->Unlock(passPhrase);
    }
}

bool WalletModel::changePassphrase(const SecureString &oldPass, const SecureString &newPass)
{
    bool retval;
    {
        LOCK(wallet->cs_wallet);
        wallet->Lock(); // Make sure wallet is locked before attempting pass change
        retval = wallet->ChangeWalletPassphrase(oldPass, newPass);
    }
    return retval;
}

// Handlers for core signals
static void NotifyKeyStoreStatusChanged(WalletModel *walletmodel, CCryptoKeyStore *wallet)
{
    LogPrintf("NotifyKeyStoreStatusChanged");
    QMetaObject::invokeMethod(walletmodel, "updateStatus", Qt::QueuedConnection);
}

static void NotifyAddressBookChanged(WalletModel *walletmodel, CWallet *wallet, const CTxDestination &address, const std::string &label, bool isMine, ChangeType status)
{
    LogPrintf("NotifyAddressBookChanged %s %s isMine=%i status=%i", EncodeDestination(address), label, isMine, status);
    QMetaObject::invokeMethod(walletmodel, "updateAddressBook", Qt::QueuedConnection,
                              Q_ARG(QString, QString::fromStdString(EncodeDestination(address))),
                              Q_ARG(QString, QString::fromStdString(label)),
                              Q_ARG(bool, isMine),
                              Q_ARG(int, status));
}

static void NotifyTransactionChanged(WalletModel *walletmodel, CWallet *wallet, const uint256 &hash, ChangeType status)
{
    LogPrint(BCLog::LogFlags::VERBOSE, "NotifyTransactionChanged %s status=%i", hash.GetHex(), status);
    QMetaObject::invokeMethod(walletmodel, "updateTransaction", Qt::QueuedConnection,
                              Q_ARG(QString, QString::fromStdString(hash.GetHex())),
                              Q_ARG(int, status));
}

void WalletModel::subscribeToCoreSignals()
{
    // Connect signals to wallet
    wallet->NotifyStatusChanged.connect(boost::bind(&NotifyKeyStoreStatusChanged, this,
                                                    boost::placeholders::_1));
    wallet->NotifyAddressBookChanged.connect(boost::bind(NotifyAddressBookChanged, this,
                                                         boost::placeholders::_1, boost::placeholders::_2,
                                                         boost::placeholders::_3, boost::placeholders::_4,
                                                         boost::placeholders::_5));
    wallet->NotifyTransactionChanged.connect(boost::bind(NotifyTransactionChanged, this,
                                                         boost::placeholders::_1, boost::placeholders::_2,
                                                         boost::placeholders::_3));
}

void WalletModel::unsubscribeFromCoreSignals()
{
    // Disconnect signals from wallet
    wallet->NotifyStatusChanged.disconnect(boost::bind(&NotifyKeyStoreStatusChanged, this,
                                                       boost::placeholders::_1));
    wallet->NotifyAddressBookChanged.disconnect(boost::bind(NotifyAddressBookChanged, this,
                                                            boost::placeholders::_1, boost::placeholders::_2,
                                                            boost::placeholders::_3, boost::placeholders::_4,
                                                            boost::placeholders::_5));
    wallet->NotifyTransactionChanged.disconnect(boost::bind(NotifyTransactionChanged, this,
                                                            boost::placeholders::_1, boost::placeholders::_2,
                                                            boost::placeholders::_3));
}

// WalletModel::UnlockContext implementation
WalletModel::UnlockContext WalletModel::requestUnlock()
{
    bool was_locked = getEncryptionStatus() == Locked;

    if ((!was_locked) && fWalletUnlockStakingOnly)
    {
       setWalletLocked(true);
       was_locked = getEncryptionStatus() == Locked;

    }
    if(was_locked)
    {
        // Request UI to unlock wallet
        emit requireUnlock();
    }
    // If wallet is still locked, unlock was failed or cancelled, mark context as invalid
    bool valid = getEncryptionStatus() != Locked;

    return UnlockContext(this, valid, was_locked && !fWalletUnlockStakingOnly);
}

WalletModel::UnlockContext::UnlockContext(WalletModel *wallet, bool valid, bool relock):
        wallet(wallet),
        valid(valid),
        relock(relock)
{
}

WalletModel::UnlockContext::~UnlockContext()
{
    if(valid && relock)
    {
        wallet->setWalletLocked(true);
    }
}

void WalletModel::UnlockContext::CopyFrom(const UnlockContext& rhs)
{
    // Transfer context; old object no longer relocks wallet
    *this = rhs;
    rhs.relock = false;
}

bool WalletModel::getPubKey(const CKeyID &address, CPubKey& vchPubKeyOut) const
{
    return wallet->GetPubKey(address, vchPubKeyOut);
}

bool WalletModel::getKeyFromPool(CPubKey& out_public_key, const std::string& label)
{
    if (!wallet->GetKeyFromPool(out_public_key, false)) {
        return false;
    }

    if (!label.empty()) {
        wallet->SetAddressBookName(out_public_key.GetID(), label);
    }

    return true;
}

// returns a list of COutputs from COutPoints
void WalletModel::getOutputs(const std::vector<COutPoint>& vOutpoints, std::vector<COutput>& vOutputs)
{
    LOCK2(cs_main, wallet->cs_wallet);
    for (auto const& outpoint : vOutpoints)
    {
        if (!wallet->mapWallet.count(outpoint.hash)) continue;
        int nDepth = wallet->mapWallet[outpoint.hash].GetDepthInMainChain();
        if (nDepth < 0) continue;
        COutput out(&wallet->mapWallet[outpoint.hash], outpoint.n, nDepth);
        vOutputs.push_back(out);
    }
}

// AvailableCoins + LockedCoins grouped by wallet address (put change in one group with wallet address)
void WalletModel::listCoins(std::map<QString, std::vector<COutput> >& mapCoins) const
{
    std::vector<COutput> vCoins;
    wallet->AvailableCoins(vCoins, true, nullptr, false);

    LOCK2(cs_main, wallet->cs_wallet); // ListLockedCoins, mapWallet

    for (auto const& out : vCoins)
    {
        COutput cout = out;

        while (wallet->IsChange(cout.tx->vout[cout.i]) && cout.tx->vin.size() > 0 && (wallet->IsMine(cout.tx->vin[0]) != ISMINE_NO))
        {
            if (!wallet->mapWallet.count(cout.tx->vin[0].prevout.hash)) break;
            cout = COutput(&wallet->mapWallet[cout.tx->vin[0].prevout.hash], cout.tx->vin[0].prevout.n, 0);
        }

        CTxDestination address;
        if(!ExtractDestination(cout.tx->vout[cout.i].scriptPubKey, address)) continue;
        mapCoins[EncodeDestination(address).c_str()].push_back(out);
    }
}

bool WalletModel::isLockedCoin(uint256 hash, unsigned int n) const
{
    return false;
}

void WalletModel::lockCoin(COutPoint& output)
{
    return;
}

void WalletModel::unlockCoin(COutPoint& output)
{
    return;
}

void WalletModel::listLockedCoins(std::vector<COutPoint>& vOutpts)
{
    return;
}
