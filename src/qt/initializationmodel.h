#ifndef GRIDCOIN_QT_INITIALIZATIONMODEL_H
#define GRIDCOIN_QT_INITIALIZATIONMODEL_H

#include <QObject>
#include <QString>

class InitializationModel : public QObject
{
    Q_OBJECT
    Q_PROPERTY(unsigned int loaded MEMBER m_loaded NOTIFY loadedChanged)
    Q_PROPERTY(unsigned int total MEMBER m_total NOTIFY loadedChanged)
    Q_PROPERTY(QString message MEMBER m_message NOTIFY messageChanged)
    Q_PROPERTY(bool startMinimized MEMBER m_startMinimized CONSTANT)
    Q_PROPERTY(bool initializationDone MEMBER m_doneLoading NOTIFY doneLoading)

public:
    explicit InitializationModel(QObject* parent = nullptr);
    void setLoadandTotal(unsigned int loaded, unsigned int total);
    void setMessage(const QString &message);
    void setStartMinimized(bool minimized);
    void setDoneLoading(bool bDone);

signals:
    void loadedChanged();
    void messageChanged();
    void showSplashScreen();
    void hideSplashScreen();
    void doneLoading();
    
private:
    QAtomicInteger<unsigned int> m_loaded = 0;
    QAtomicInteger<unsigned int> m_total = 0;
    QString m_message;
    bool m_startMinimized = false;
    bool m_doneLoading = false;
};

#endif // GRIDCOIN_QT_INITIALIZATIONMODEL_H
