#include "initializationmodel.h"


InitializationModel::InitializationModel(QObject* parent)
    : QObject{parent}
{
}

void InitializationModel::setLoadandTotal(unsigned int loaded, unsigned int total) 
{
    m_loaded = loaded;
    m_total = total;
    emit loadedChanged();
}

void InitializationModel::setMessage(const QString &message) 
{
    m_message = message;
    emit messageChanged();
}

void InitializationModel::setStartMinimized(bool minimized) {
    m_startMinimized = minimized;
}

void InitializationModel::setDoneLoading(bool bDone) {
    m_doneLoading = bDone;
    emit doneLoading();
}
