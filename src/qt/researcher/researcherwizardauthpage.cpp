// Copyright (c) 2014-2021 The Gridcoin developers
// Distributed under the MIT/X11 software license, see the accompanying
// file COPYING or https://opensource.org/licenses/mit-license.php.

#include "qt/decoration.h"
#include "qt/forms/ui_researcherwizardauthpage.h"
#include "qt/researcher/researchermodel.h"
#include "qt/researcher/researcherwizardauthpage.h"

#include <QClipboard>

// -----------------------------------------------------------------------------
// Class: ResearcherWizardAuthPage
// -----------------------------------------------------------------------------

ResearcherWizardAuthPage::ResearcherWizardAuthPage(QWidget *parent)
    : QWizardPage(parent)
    , ui(new Ui::ResearcherWizardAuthPage)
    , m_researcher_model(nullptr)
{
    ui->setupUi(this);

    GRC::ScaleFontPointSize(ui->verificationCodeLabel, 10);
}

ResearcherWizardAuthPage::~ResearcherWizardAuthPage()
{
    delete ui;
}

void ResearcherWizardAuthPage::setModel(ResearcherModel* researcher_model)
{
    this->m_researcher_model = researcher_model;

    if (!m_researcher_model) {
        return;
    }

    connect(m_researcher_model, &ResearcherModel::researcherChanged, this, &ResearcherWizardAuthPage::refresh);
}

void ResearcherWizardAuthPage::initializePage()
{
    if (!m_researcher_model) {
        return;
    }

    refresh();
}

void ResearcherWizardAuthPage::refresh()
{
    if (!m_researcher_model) {
        return;
    }

    ui->verificationCodeLabel->setText(m_researcher_model->formatBeaconVerificationCode());
}

void ResearcherWizardAuthPage::on_copyToClipboardButton_clicked()
{
    QApplication::clipboard()->setText(ui->verificationCodeLabel->text());
}
