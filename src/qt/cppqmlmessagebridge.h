#ifndef GRIDCOIN_QT_CPPQMLMESSAGEBRIDGE_H
#define GRIDCOIN_QT_CPPQMLMESSAGEBRIDGE_H

#include <QObject>
#include <QString>

class CppQmlMessageBridge : public QObject
{
    Q_OBJECT
public:
    explicit CppQmlMessageBridge(QObject* parent = nullptr);

signals:
    void newInitMessage(const QString &message);

public slots:
    void postInitMessage(const QString &message);
};

#endif // GRIDCOIN_QT_CPPQMLMESSAGEBRIDGE_H
