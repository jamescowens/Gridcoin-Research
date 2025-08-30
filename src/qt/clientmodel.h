#ifndef BITCOIN_QT_CLIENTMODEL_H
#define BITCOIN_QT_CLIENTMODEL_H

#include <QObject>

#include <atomic>

class OptionsModel;
class AddressTableModel;
class TransactionTableModel;
class BanTableModel;
class PeerTableModel;

struct ConvergedScraperStats;
class CWallet;

QT_BEGIN_NAMESPACE
class QDateTime;
class QTimer;
QT_END_NAMESPACE

/** Model for Bitcoin network client. */
class ClientModel : public QObject
{
    Q_OBJECT
    Q_PROPERTY(int numBlocks READ getNumBlocks NOTIFY numBlocksChanged)
    Q_PROPERTY(int numBlocksPeers READ getNumBlocksOfPeers NOTIFY numBlocksChanged)
    Q_PROPERTY(double difficulty READ getDifficulty NOTIFY difficultyChanged)
    Q_PROPERTY(double networkWeight READ getNetWeight NOTIFY numBlocksChanged)
    Q_PROPERTY(double coinWeight READ getCoinWeight NOTIFY minerStatusChanged)

    Q_PROPERTY(bool inSync READ inSync NOTIFY numBlocksChanged)
    
    // Q_PROPERTY(QDateTime bestBlockTime READ getLastBlockDate NOTIFY numBlocksChanged)
    // Q_PROPERTY(int numConnections READ getNumConnections NOTIFY numConnectionsChanged)
    // Q_PROPERTY(quint64 totalBytesRecv READ getTotalBytesRecv NOTIFY bytesChanged)
    // Q_PROPERTY(quint64 totalBytesSent READ getTotalBytesSent NOTIFY bytesChanged)

    Q_PROPERTY(bool isTestNet READ isTestNet CONSTANT)
    // Q_PROPERTY(bool inInitialBlockDownload READ inInitialBlockDownload CONSTANT)

    Q_PROPERTY(QString statusBarWarnings READ getStatusBarWarnings NOTIFY numBlocksChanged)
    Q_PROPERTY(QString minerWarnings READ getMinerWarnings NOTIFY minerStatusChanged)

    // Q_PROPERTY(QString fullVersion READ formatFullVersion CONSTANT)
    // Q_PROPERTY(QString clientName READ clientName CONSTANT)
    // Q_PROPERTY(QString startupTime READ formatClientStartupTime CONSTANT)
    // Q_PROPERTY(QString boostVersion READ formatBoostVersion CONSTANT)

public:
    explicit ClientModel(OptionsModel* optionsModel, QObject* parent = nullptr);
    ~ClientModel();

    OptionsModel *getOptionsModel();
    PeerTableModel *getPeerTableModel();
    BanTableModel *getBanTableModel();

    int getNumConnections() const;
    int getNumBlocks() const;
	quint64 getTotalBytesRecv() const;
    quint64 getTotalBytesSent() const;


    QDateTime getLastBlockDate() const;

    //! Return true if client connected to testnet
    bool isTestNet() const;
    //! Return true if core is doing initial block download
    bool inInitialBlockDownload() const;
    //! Return conservative estimate of total number of blocks, or 0 if unknown
    int getNumBlocksOfPeers() const;
    //! Return the difficulty of the block at the chain tip.
    double getDifficulty() const;
    //! Return estimated network staking weight from the average of recent blocks.
    double getNetWeight() const;
    //! Return warnings to be displayed in status bar
    QString getStatusBarWarnings() const;
    //! Get miner and staking status warnings
    QString getMinerWarnings() const;
    //! Is client in sync
    bool inSync() const;

    QString formatFullVersion() const;
    QString clientName() const;
    QString formatClientStartupTime() const;

    QString formatBoostVersion()  const;
    const ConvergedScraperStats& getConvergedScraperStatsCache() const;
private:
    OptionsModel *optionsModel;
    PeerTableModel *peerTableModel;
    BanTableModel *banTableModel;

    mutable std::atomic<int> m_cached_num_blocks;
    mutable std::atomic<int> m_cached_num_blocks_of_peers;
    mutable std::atomic<int64_t> m_cached_best_block_time;
    mutable std::atomic<double> m_cached_difficulty;
    mutable std::atomic<double> m_cached_net_weight;
    mutable std::atomic<double> m_cached_etts_days;

    QTimer *pollTimer;

    void subscribeToCoreSignals();
    void unsubscribeFromCoreSignals();
    double getCoinWeight() const;
signals:
    void numConnectionsChanged(int count);
    void numBlocksChanged(int count, int countOfPeers);
    void difficultyChanged(double difficulty);
	void bytesChanged(quint64 totalBytesIn, quint64 totalBytesOut);
    void minerStatusChanged(bool staking, double netWeight, double coinWeight, double etts_days);
    void updateScraperLog(QString message);
    void updateScraperStatus(int ScraperEventtype, int status);

    //! Asynchronous error notification
    void error(const QString &title, const QString &message, bool modal);

public slots:
    void updateNumBlocks(int height, int64_t best_time, uint32_t target_bits);
    void updateTimer();
    void updateBanlist();
    void updateNumConnections(int numConnections);
    void updateAlert(const QString &hash, int status);
    void updateMinerStatus(bool staking, double coin_weight);
    void updateScraper(int scraperEventtype, int status, const QString message);
};

#endif // BITCOIN_QT_CLIENTMODEL_H
