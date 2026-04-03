// Copyright (c) 2014-2021 The Gridcoin developers
// Distributed under the MIT/X11 software license, see the accompanying
// file COPYING or https://opensource.org/licenses/mit-license.php.

#ifndef GRIDCOIN_QT_RESEARCHER_RESEARCHERWIZARDNONCRUNCHERPAGE_H
#define GRIDCOIN_QT_RESEARCHER_RESEARCHERWIZARDNONCRUNCHERPAGE_H

#include <QWizardPage>

class QIcon;
class ResearcherModel;

namespace Ui {
class ResearcherWizardNoncruncherPage;
}

class ResearcherWizardNoncruncherPage : public QWizardPage
{
    Q_OBJECT

public:
    explicit ResearcherWizardNoncruncherPage(QWidget *parent = nullptr);
    ~ResearcherWizardNoncruncherPage();

    void setModel(ResearcherModel *researcher_model);

    void initializePage() override;
    int nextId() const override;

private:
    Ui::ResearcherWizardNoncruncherPage *ui;
    ResearcherModel *m_researcher_model;
};

#endif // GRIDCOIN_QT_RESEARCHER_RESEARCHERWIZARDNONCRUNCHERPAGE_H
