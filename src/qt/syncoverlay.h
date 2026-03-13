// Copyright (c) 2025 The Gridcoin developers
// Distributed under the MIT/X11 software license, see the accompanying
// file COPYING or https://opensource.org/licenses/mit-license.php.

#ifndef BITCOIN_QT_SYNCOVERLAY_H
#define BITCOIN_QT_SYNCOVERLAY_H

#include <QWidget>

class QLabel;
class QPushButton;

//!
//! \brief A semi-transparent overlay that covers the main window's central
//! widget while the wallet is not in sync.
//!
//! This prevents users from interacting with features that require an
//! up-to-date chain state (beacon management, voting, etc.) before the
//! wallet has finished synchronizing.
//!
//! The overlay can be dismissed for the current sync cycle by clicking the
//! "Hide" button, after which the user can browse the wallet freely (with
//! per-action guards still in place for dangerous operations). If the wallet
//! later reaches in-sync and then falls out of sync again, the overlay will
//! reappear.
//!
class SyncOverlay : public QWidget
{
    Q_OBJECT

public:
    explicit SyncOverlay(QWidget* parent);

    //! Update the overlay visibility based on the current sync state.
    //! When \p out_of_sync is true and the overlay has not been dismissed,
    //! it is raised to the front and shown. When false, it is hidden.
    void setSyncState(bool out_of_sync, int blocks, int total_blocks);

    //! Returns true if the overlay is logically active (wallet is out of
    //! sync and the user has not dismissed the overlay).
    bool isActive() const;

protected:
    bool eventFilter(QObject* watched, QEvent* event) override;
    void paintEvent(QPaintEvent* event) override;

private slots:
    void dismiss();

private:
    QLabel* m_icon_label;
    QLabel* m_title_label;
    QLabel* m_detail_label;
    QPushButton* m_hide_button;
    bool m_dismissed;
    bool m_out_of_sync;
};

#endif // BITCOIN_QT_SYNCOVERLAY_H
