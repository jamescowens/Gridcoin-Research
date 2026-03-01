// Copyright (c) 2014-2025 The Gridcoin developers
// Distributed under the MIT/X11 software license, see the accompanying
// file COPYING or https://opensource.org/licenses/mit-license.php.

#ifndef GRIDCOIN_QT_RESEARCHER_RESEARCHERWIZARDOWNERSHIPPROOFPAGE_H
#define GRIDCOIN_QT_RESEARCHER_RESEARCHERWIZARDOWNERSHIPPROOFPAGE_H

#include <QWizardPage>

class QIcon;
class ResearcherModel;
class WalletModel;

namespace Ui {
class ResearcherWizardOwnershipProofPage;
}

class ResearcherWizardOwnershipProofPage : public QWizardPage
{
    Q_OBJECT

public:
    explicit ResearcherWizardOwnershipProofPage(QWidget *parent = nullptr);
    ~ResearcherWizardOwnershipProofPage();

    void setModel(ResearcherModel *researcher_model, WalletModel *wallet_model);

    void initializePage() override;
    bool isComplete() const override;
    int nextId() const override;

private:
    Ui::ResearcherWizardOwnershipProofPage *ui;
    ResearcherModel *m_researcher_model;
    WalletModel *m_wallet_model;
    bool m_beacon_sent;

private slots:
    void copyPubKeyToClipboard();
    void submitOwnershipProof();
    void updateStatusIcon(const QIcon& icon);
};

#endif // GRIDCOIN_QT_RESEARCHER_RESEARCHERWIZARDOWNERSHIPPROOFPAGE_H
