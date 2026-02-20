#ifndef BITCOIN_QT_TEST_BITCOINUNITSTESTS_H
#define BITCOIN_QT_TEST_BITCOINUNITSTESTS_H

#include <QTest>
#include <QObject>

class BitcoinUnitsTests : public QObject
{
    Q_OBJECT

private slots:
    void formatTests();
    void parseTests();
};

#endif // BITCOIN_QT_TEST_BITCOINUNITSTESTS_H
