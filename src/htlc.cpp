// Copyright (c) 2024-2026 The Gridcoin developers
// Distributed under the MIT software license, see the accompanying
// file COPYING or https://opensource.org/licenses/mit-license.php.

#include "htlc.h"
#include "key.h"

CScript CreateHTLCScript(
    const std::vector<unsigned char>& hash,
    const CPubKey& receiver_pubkey,
    const CPubKey& sender_pubkey,
    int64_t timeout)
{
    CScript script;

    script << OP_IF;
    script << OP_SHA256;
    script << hash;
    script << OP_EQUALVERIFY;
    script << receiver_pubkey;
    script << OP_CHECKSIG;
    script << OP_ELSE;
    script << CScriptNum(timeout);
    script << OP_CHECKLOCKTIMEVERIFY;
    script << OP_DROP;
    script << sender_pubkey;
    script << OP_CHECKSIG;
    script << OP_ENDIF;

    return script;
}

CScript CreateHTLCClaimScript(
    const std::vector<unsigned char>& sig,
    const std::vector<unsigned char>& preimage,
    const CScript& redeemScript)
{
    CScript scriptSig;

    scriptSig << sig;
    scriptSig << preimage;
    scriptSig << OP_TRUE;  // Select the OP_IF (claim) branch

    // Serialize the redeem script as a push data element
    scriptSig << std::vector<unsigned char>(redeemScript.begin(), redeemScript.end());

    return scriptSig;
}

CScript CreateHTLCRefundScript(
    const std::vector<unsigned char>& sig,
    const CScript& redeemScript)
{
    CScript scriptSig;

    scriptSig << sig;
    scriptSig << OP_FALSE;  // Select the OP_ELSE (refund) branch

    // Serialize the redeem script as a push data element
    scriptSig << std::vector<unsigned char>(redeemScript.begin(), redeemScript.end());

    return scriptSig;
}

bool ParseHTLCScript(
    const CScript& script,
    std::vector<unsigned char>& hash_out,
    CPubKey& receiver_out,
    CPubKey& sender_out,
    int64_t& timeout_out)
{
    // Expected structure:
    //   OP_IF
    //     OP_SHA256 <hash:32> OP_EQUALVERIFY <receiver_pubkey> OP_CHECKSIG
    //   OP_ELSE
    //     <timeout> OP_CHECKLOCKTIMEVERIFY OP_DROP <sender_pubkey> OP_CHECKSIG
    //   OP_ENDIF

    CScript::const_iterator pc = script.begin();
    opcodetype opcode;
    std::vector<unsigned char> data;

    // 1. OP_IF
    if (!script.GetOp(pc, opcode) || opcode != OP_IF)
        return false;

    // 2. OP_SHA256
    if (!script.GetOp(pc, opcode) || opcode != OP_SHA256)
        return false;

    // 3. <hash> (32 bytes)
    if (!script.GetOp(pc, opcode, data) || data.size() != 32)
        return false;
    hash_out = data;

    // 4. OP_EQUALVERIFY
    if (!script.GetOp(pc, opcode) || opcode != OP_EQUALVERIFY)
        return false;

    // 5. <receiver_pubkey>
    if (!script.GetOp(pc, opcode, data))
        return false;
    receiver_out = CPubKey(data.begin(), data.end());
    if (!receiver_out.IsValid())
        return false;

    // 6. OP_CHECKSIG
    if (!script.GetOp(pc, opcode) || opcode != OP_CHECKSIG)
        return false;

    // 7. OP_ELSE
    if (!script.GetOp(pc, opcode) || opcode != OP_ELSE)
        return false;

    // 8. <timeout> (CScriptNum encoded)
    if (!script.GetOp(pc, opcode, data))
        return false;
    // The timeout is pushed as data (it's a CScriptNum)
    try {
        CScriptNum num(data, false, 5);
        timeout_out = num.GetInt64();
    } catch (const scriptnum_error&) {
        return false;
    }

    // 9. OP_CHECKLOCKTIMEVERIFY
    if (!script.GetOp(pc, opcode) || opcode != OP_CHECKLOCKTIMEVERIFY)
        return false;

    // 10. OP_DROP
    if (!script.GetOp(pc, opcode) || opcode != OP_DROP)
        return false;

    // 11. <sender_pubkey>
    if (!script.GetOp(pc, opcode, data))
        return false;
    sender_out = CPubKey(data.begin(), data.end());
    if (!sender_out.IsValid())
        return false;

    // 12. OP_CHECKSIG
    if (!script.GetOp(pc, opcode) || opcode != OP_CHECKSIG)
        return false;

    // 13. OP_ENDIF
    if (!script.GetOp(pc, opcode) || opcode != OP_ENDIF)
        return false;

    // Should be at the end of the script
    if (pc != script.end())
        return false;

    return true;
}
