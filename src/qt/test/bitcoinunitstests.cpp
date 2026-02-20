#include "bitcoinunitstests.h"
#include "../bitcoinunits.h"

void BitcoinUnitsTests::formatTests()
{
    const QChar ts = BitcoinUnits::THIN_SPACE;

    // Small amounts (no thousands separator expected)
    QCOMPARE(BitcoinUnits::format(BitcoinUnits::BTC, 0), QString("0.00"));
    QCOMPARE(BitcoinUnits::format(BitcoinUnits::BTC, 100000000), QString("1.00"));
    QCOMPARE(BitcoinUnits::format(BitcoinUnits::BTC, 99900000000LL), QString("999.00"));

    // 4-digit integer part: one thin space separator
    QCOMPARE(BitcoinUnits::format(BitcoinUnits::BTC, 100000000000LL),
             QString("1") + ts + QString("000.00"));

    // 5-digit integer part
    QCOMPARE(BitcoinUnits::format(BitcoinUnits::BTC, 1234500000000LL),
             QString("12") + ts + QString("345.00"));

    // 7-digit integer part: two thin space separators
    QCOMPARE(BitcoinUnits::format(BitcoinUnits::BTC, 123456789012345LL),
             QString("1") + ts + QString("234") + ts + QString("567.89012345"));

    // Negative amount
    QCOMPARE(BitcoinUnits::format(BitcoinUnits::BTC, -123456789012345LL),
             QString("-1") + ts + QString("234") + ts + QString("567.89012345"));

    // Plus sign
    QCOMPARE(BitcoinUnits::format(BitcoinUnits::BTC, 123456789012345LL, true),
             QString("+1") + ts + QString("234") + ts + QString("567.89012345"));

    // mBTC unit with separators
    QCOMPARE(BitcoinUnits::format(BitcoinUnits::mBTC, 100000000000LL),
             QString("1") + ts + QString("000") + ts + QString("000.00"));

    // uBTC unit with separators
    QCOMPARE(BitcoinUnits::format(BitcoinUnits::uBTC, 100000000000LL),
             QString("1") + ts + QString("000") + ts + QString("000") + ts + QString("000.00"));
}

void BitcoinUnitsTests::parseTests()
{
    const QChar ts = BitcoinUnits::THIN_SPACE;
    qint64 val;

    // Parse plain value (no separators)
    QVERIFY(BitcoinUnits::parse(BitcoinUnits::BTC, "1234.56", &val));
    QCOMPARE(val, 123456000000LL);

    // Parse value with thin space separators (as produced by format)
    QString formatted = QString("1") + ts + QString("234.56");
    QVERIFY(BitcoinUnits::parse(BitcoinUnits::BTC, formatted, &val));
    QCOMPARE(val, 123456000000LL);

    // Round-trip: format then parse
    qint64 original = 123456789012345LL;
    QString str = BitcoinUnits::format(BitcoinUnits::BTC, original);
    qint64 parsed;
    QVERIFY(BitcoinUnits::parse(BitcoinUnits::BTC, str, &parsed));
    QCOMPARE(parsed, original);

    // Round-trip with mBTC
    original = 100000000000LL;
    str = BitcoinUnits::format(BitcoinUnits::mBTC, original);
    QVERIFY(BitcoinUnits::parse(BitcoinUnits::mBTC, str, &parsed));
    QCOMPARE(parsed, original);
}
