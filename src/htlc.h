// Copyright (c) 2024-2026 The Gridcoin developers
// Distributed under the MIT software license, see the accompanying
// file COPYING or https://opensource.org/licenses/mit-license.php.

#ifndef GRIDCOIN_HTLC_H
#define GRIDCOIN_HTLC_H

#include "script.h"

#include <vector>

class CPubKey;

/**
 * Create an HTLC (Hash Time-Locked Contract) redeem script.
 *
 * The script template is:
 *   OP_IF
 *     OP_SHA256 <hash> OP_EQUALVERIFY <receiver_pubkey> OP_CHECKSIG
 *   OP_ELSE
 *     <timeout> OP_CHECKLOCKTIMEVERIFY OP_DROP <sender_pubkey> OP_CHECKSIG
 *   OP_ENDIF
 *
 * @param hash              SHA256 hash of the preimage (32 bytes)
 * @param receiver_pubkey   Public key of the receiver (claim path)
 * @param sender_pubkey     Public key of the sender (refund path)
 * @param timeout           Absolute locktime for the refund path
 * @return The constructed HTLC redeem script
 */
CScript CreateHTLCScript(
    const std::vector<unsigned char>& hash,
    const CPubKey& receiver_pubkey,
    const CPubKey& sender_pubkey,
    int64_t timeout);

/**
 * Create the scriptSig to claim an HTLC output (preimage + signature path).
 *
 * @param sig            Signature from the receiver
 * @param preimage       The preimage whose SHA256 matches the hash in the script
 * @param redeemScript   The full HTLC redeem script
 * @return The scriptSig for the claim spending transaction
 */
CScript CreateHTLCClaimScript(
    const std::vector<unsigned char>& sig,
    const std::vector<unsigned char>& preimage,
    const CScript& redeemScript);

/**
 * Create the scriptSig to refund an HTLC output (timeout path).
 *
 * @param sig            Signature from the sender
 * @param redeemScript   The full HTLC redeem script
 * @return The scriptSig for the refund spending transaction
 */
CScript CreateHTLCRefundScript(
    const std::vector<unsigned char>& sig,
    const CScript& redeemScript);

/**
 * Parse an HTLC redeem script to extract its components.
 *
 * @param script        The script to parse
 * @param hash_out      Receives the SHA256 hash (32 bytes)
 * @param receiver_out  Receives the receiver's public key
 * @param sender_out    Receives the sender's public key
 * @param timeout_out   Receives the absolute locktime
 * @return true if the script matches the HTLC template
 */
bool ParseHTLCScript(
    const CScript& script,
    std::vector<unsigned char>& hash_out,
    CPubKey& receiver_out,
    CPubKey& sender_out,
    int64_t& timeout_out);

#endif // GRIDCOIN_HTLC_H
