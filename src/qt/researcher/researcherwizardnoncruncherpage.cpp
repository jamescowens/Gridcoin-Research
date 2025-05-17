// Copyright (c) 2014-2021 The Gridcoin developers
// Distributed under the MIT/X11 software license, see the accompanying
// file COPYING or https://opensource.org/licenses/mit-license.php.

#include "qt/decoration.h"
#include "qt/forms/ui_researcherwizardnoncruncherpage.h"
#include "qt/researcher/researchermodel.h"
#include "qt/researcher/researcherwizard.h"
#include "qt/researcher/researcherwizardnoncruncherpage.h"

// -----------------------------------------------------------------------------
// Class: ResearcherWizardNoncruncherPage
// -----------------------------------------------------------------------------

ResearcherWizardNoncruncherPage::ResearcherWizardNoncruncherPage(QWidget *parent)
    : QWizardPage(parent)
    , ui(new Ui::ResearcherWizardNoncruncherPage)
{
    ui->setupUi(this);

    GRC::ScaleFontPointSize(ui->headerLabel, 11);
}

ResearcherWizardNoncruncherPage::~ResearcherWizardNoncruncherPage()
{
    delete ui;
}

void ResearcherWizardNoncruncherPage::setModel(ResearcherModel* researcher_model)
{
    this->m_researcher_model = researcher_model;
}

void ResearcherWizardNoncruncherPage::initializePage()
{
    if (!m_researcher_model) {
        return;
    }

    m_researcher_model->switchToNoncruncher();
}

int ResearcherWizardNoncruncherPage::nextId() const
{
    // Force this page to be a final page. Since the wizard has multiple final
    // pages, we need to return this value to ensure that no "back" and "next"
    // buttons appear on this page. The setFinalPage() method is not enough.
    //
    return -1;
}
