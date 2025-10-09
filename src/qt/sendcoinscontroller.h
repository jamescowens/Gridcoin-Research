#ifndef GRIDCOIN_QT_SENDCOINSCONTROLLER_H
#define GRIDCOIN_QT_SENDCOINSCONTROLLER_H

#include <QObject>
#include <QVariantList>

#include "walletmodel.h"

class SendCoinsController : public QObject
{
    Q_OBJECT
    Q_PROPERTY(QVariantList recipients READ getRecipients NOTIFY recipientsChanged)

public:
    explicit SendCoinsController(WalletModel &wallet_model, QObject *parent = nullptr);

    Q_INVOKABLE void addRecipient();
    Q_INVOKABLE void removeRecipient(int index);
    Q_INVOKABLE void updateRecipient(int index, const QVariantMap &data);
    Q_INVOKABLE void clearRecipients();

    QVariantList getRecipients() const;

signals:
    void recipientsChanged();
    void coinsSentOrFailed(const QString &result_message);

public slots:
    void sendCoins();

private:
    WalletModel &m_wallet_model;
    QList<SendCoinsRecipient> m_recipients;

    void updateRecipients();
};

#endif // GRIDCOIN_QT_SENDCOINSCONTROLLER_H
