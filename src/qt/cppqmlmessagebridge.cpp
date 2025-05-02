#include "cppqmlmessagebridge.h"


CppQmlMessageBridge::CppQmlMessageBridge(QObject* parent)
    : QObject{parent}
{
}

void CppQmlMessageBridge::postInitMessage(const QString &message) 
{
    emit newInitMessage(message);
}
