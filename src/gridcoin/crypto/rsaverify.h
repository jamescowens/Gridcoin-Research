// Copyright (c) 2014-2026 The Gridcoin developers
// Distributed under the MIT/X11 software license, see the accompanying
// file COPYING or https://opensource.org/licenses/mit-license.php.

#ifndef GRIDCOIN_CRYPTO_RSAVERIFY_H
#define GRIDCOIN_CRYPTO_RSAVERIFY_H

#include <cstdint>
#include <string>
#include <vector>

namespace GRC {

//!
//! \brief Verify an RSA-SHA512 signature using a PEM-encoded public key.
//!
//! This is used to verify BOINC proof-of-ownership signatures, where a BOINC
//! project signs a message with its RSA private key and provides the signature
//! for third-party verification.
//!
//! \param message    The message bytes that were signed.
//! \param signature  The RSA signature bytes to verify.
//! \param pem_pubkey The PEM-encoded RSA public key (-----BEGIN PUBLIC KEY-----).
//!
//! \return \c true if the signature is valid for the given message and key.
//!
bool VerifyRSASHA512(
    const std::vector<uint8_t>& message,
    const std::vector<uint8_t>& signature,
    const std::string& pem_pubkey);

} // namespace GRC

#endif // GRIDCOIN_CRYPTO_RSAVERIFY_H
