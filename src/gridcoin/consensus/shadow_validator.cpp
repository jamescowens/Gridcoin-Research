// Copyright (c) 2026 The Gridcoin developers
// Distributed under the MIT software license, see the accompanying
// file COPYING or https://opensource.org/licenses/mit-license.php.

#include "gridcoin/consensus/shadow_validator.h"
#include "main.h"
#include "util.h"

#include <fstream>
#include <mutex>

using namespace GRC;

namespace {

//! Implementation selector: "old" or "new".
std::string g_consensus_impl = "old";

//! Whether to run the shadow (alternate) implementation alongside authoritative.
bool g_shadow_enabled = false;

//! Optional structured log file for shadow comparison results.
std::ofstream g_shadow_log_file;
std::mutex g_shadow_log_mutex;

//! Write a JSON-lines entry to the shadow log file (if open) and to debug log.
void LogShadowResult(
    int height,
    const uint256& block_hash,
    const std::string& component,
    bool auth_pass,
    bool shadow_pass,
    const std::string& auth_error,
    const std::string& shadow_error,
    int64_t auth_ms,
    int64_t shadow_ms)
{
    bool mismatch = (auth_pass != shadow_pass);

    if (mismatch) {
        LogPrintf("ERROR: ShadowValidator: MISMATCH at height %d hash %s component=%s: "
                  "auth(impl=%s)=%d shadow=%d auth_error='%s' shadow_error='%s' "
                  "auth_ms=%d shadow_ms=%d",
                  height, block_hash.ToString(), component,
                  g_consensus_impl, auth_pass, shadow_pass,
                  auth_error, shadow_error,
                  auth_ms, shadow_ms);
    } else {
        LogPrint(BCLog::LogFlags::VERBOSE, "INFO: ShadowValidator: height %d component=%s match OK | "
                  "auth_ms=%d shadow_ms=%d",
                  height, component, auth_ms, shadow_ms);
    }

    // Write to structured log file if open.
    if (g_shadow_log_file.is_open()) {
        std::lock_guard<std::mutex> lock(g_shadow_log_mutex);

        g_shadow_log_file
            << "{\"height\":" << height
            << ",\"block_hash\":\"" << block_hash.ToString() << "\""
            << ",\"component\":\"" << component << "\""
            << ",\"auth_impl\":\"" << g_consensus_impl << "\""
            << ",\"auth_pass\":" << (auth_pass ? "true" : "false")
            << ",\"shadow_pass\":" << (shadow_pass ? "true" : "false");

        if (!auth_error.empty()) {
            g_shadow_log_file << ",\"auth_error\":\"" << auth_error << "\"";
        }
        if (!shadow_error.empty()) {
            g_shadow_log_file << ",\"shadow_error\":\"" << shadow_error << "\"";
        }

        g_shadow_log_file
            << ",\"auth_ms\":" << auth_ms
            << ",\"shadow_ms\":" << shadow_ms
            << "}\n";

        g_shadow_log_file.flush();
    }
}

} // anonymous namespace

// -----------------------------------------------------------------------------
// Public interface
// -----------------------------------------------------------------------------

void GRC::InitShadowValidator()
{
    g_consensus_impl = gArgs.GetArg("-consensusrulesimpl", "old");
    g_shadow_enabled = gArgs.GetBoolArg("-consensusrulesshadow", false);

    if (g_shadow_enabled) {
        LogPrintf("WARNING: Consensus shadow mode is active — this is a development/validation mode only. "
                  "Authoritative implementation: %s", g_consensus_impl);

        std::string log_path = gArgs.GetArg("-consensusshadowlog", "");
        if (!log_path.empty()) {
            g_shadow_log_file.open(log_path, std::ios::out | std::ios::app);
            if (g_shadow_log_file.is_open()) {
                LogPrintf("ShadowValidator: writing structured log to %s", log_path);
            } else {
                LogPrintf("ERROR: ShadowValidator: could not open shadow log file %s", log_path);
            }
        }
    }
}

bool GRC::IsNewImplAuthoritative()
{
    return g_consensus_impl == "new";
}

bool GRC::IsShadowValidationEnabled()
{
    return g_shadow_enabled;
}

void GRC::LogShadowComparison(
    int height,
    const uint256& block_hash,
    bool auth_pass,
    bool shadow_pass,
    const std::string& auth_error,
    const std::string& shadow_error,
    int64_t auth_ms,
    int64_t shadow_ms)
{
    LogShadowResult(
        height,
        block_hash,
        "full_claim",
        auth_pass,
        shadow_pass,
        auth_error,
        shadow_error,
        auth_ms,
        shadow_ms);
}

void GRC::ShutdownShadowValidator()
{
    if (g_shadow_log_file.is_open()) {
        g_shadow_log_file.close();
        LogPrintf("ShadowValidator: closed shadow log file");
    }
}
