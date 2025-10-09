#include "sendcoinscontroller.h"
#include "bitcoinunits.h"
#include "guiutil.h"
#include "wallet/wallet.h"
#include "policy/policy.h"

#include <QMessageBox>

SendCoinsController::SendCoinsController(WalletModel &wallet_model, QObject *parent)
    : QObject(parent)
    , m_wallet_model(wallet_model)
{
    addRecipient();
}

QVariantList SendCoinsController::getRecipients() const
{
    QVariantList list;
    for (const auto& rcp : m_recipients) {
        QVariantMap map;
        map.insert("recipient", rcp.address);
        map.insert("label", rcp.label);
        map.insert("message", rcp.Message);
        map.insert("amount", BitcoinUnits::halfordsToGrc(rcp.amount));
        list.append(map);
    }
    return list;
}

void SendCoinsController::addRecipient()
{
    SendCoinsRecipient rcp;
    rcp.address = "";
    rcp.amount = 0;
    rcp.label = "";
    rcp.Message = "";
    m_recipients.append(rcp);
    emit recipientsChanged();
}

void SendCoinsController::removeRecipient(int index)
{
    if (index >= 0 && index < m_recipients.size()) {
        m_recipients.removeAt(index);
        emit recipientsChanged();
    }
}

void SendCoinsController::updateRecipient(int index, const QVariantMap &data)
{
    if (index >= 0 && index < m_recipients.size()) {
        SendCoinsRecipient& rcp = m_recipients[index];
        if (data.contains("recipient"))
            rcp.address = data.value("recipient").toString();
        if (data.contains("label"))
            rcp.label = data.value("label").toString();
        if (data.contains("message"))
            rcp.Message = data.value("message").toString();
        if (data.contains("amount"))
            rcp.amount = BitcoinUnits::GrcToHalfords(data.value("amount").toString());
        emit recipientsChanged();
    }
}

void SendCoinsController::clearRecipients() {
    m_recipients.clear();
    emit recipientsChanged();
}

void SendCoinsController::sendCoins()
{
    if (m_recipients.isEmpty()) {
        emit coinsSentOrFailed(tr("No recipients."));
        return;
    }

    for (const auto& rcp : m_recipients) {
        if (!m_wallet_model.validateAddress(rcp.address)) {
            emit coinsSentOrFailed(tr("Invalid address: ") + rcp.address);
            return;
        }
    }

    QFuture<WalletModel::UnlockContext> unlockFuture = m_wallet_model.requestUnlock();
    unlockFuture.then([this](QFuture<WalletModel::UnlockContext> future) -> void {
        WalletModel::UnlockContext ctx = future.result();
        if (!ctx.isValid()) {
            emit coinsSentOrFailed(tr("Wallet unlock was cancelled."));
            return;
        }
        
        QFuture<WalletModel::SendCoinsReturn> sendFuture = m_wallet_model.sendCoins(m_recipients);
        sendFuture.then([this](WalletModel::SendCoinsReturn sendstatus) {
            switch (sendstatus.status) {
            case WalletModel::InvalidAddress:
                emit coinsSentOrFailed(tr("The recipient address is not valid, please recheck."));
                return;
            case WalletModel::InvalidAmount:
                emit coinsSentOrFailed(tr("The amount to pay must be larger than 0."));
                return;
            case WalletModel::AmountExceedsBalance:
                emit coinsSentOrFailed(tr("The amount exceeds your balance."));
                return;
            case WalletModel::AmountWithFeeExceedsBalance:
                emit coinsSentOrFailed(tr("The total exceeds your balance when the %1 transaction fee is included.")
                                .arg(BitcoinUnits::formatWithUnit(BitcoinUnits::BTC, sendstatus.fee)));
                return;
            case WalletModel::DuplicateAddress:
                emit coinsSentOrFailed(tr("Duplicate address found, can only send to each address once per send operation."));
                return;
            case WalletModel::TransactionCreationFailed:
                emit coinsSentOrFailed(tr("Error: Transaction creation failed."));
                return;
            case WalletModel::TransactionCommitFailed:
                emit coinsSentOrFailed(tr("Error: The transaction was rejected. This might happen if some of the coins in your wallet were already) spent, such as if you used a copy of wallet.dat and coins were spent in the copy but not marked as spent here."));
                return;
            case WalletModel::Aborted: // User aborted, nothing to do
                emit coinsSentOrFailed(tr("Send aborted."));
                return;
            case WalletModel::OK:
                // Clear recipients after successful send
                m_recipients.clear();
                addRecipient(); // Add a fresh one
                emit recipientsChanged();
                emit coinsSentOrFailed(tr("Transaction sent successfully!"));
                return;
            }
            emit coinsSentOrFailed(tr("Unknown error."));
        });
    });
}
