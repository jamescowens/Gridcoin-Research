// Copyright (c) 2014-2021 The Gridcoin developers
// Distributed under the MIT/X11 software license, see the accompanying
// file COPYING or https://opensource.org/licenses/mit-license.php.

#include "gridcoin/boinc.h"
#include "util.h"

#include <vector>

fs::path GRC::GetBoincDataDir()
{
    std::string path = gArgs.GetArg("-boincdatadir", "");

    if (!path.empty()) {
        return fs::path(path);
    }

    #ifdef WIN32
    HKEY hKey;
    if (RegOpenKeyEx(
        HKEY_LOCAL_MACHINE,
        L"SOFTWARE\\Space Sciences Laboratory, U.C. Berkeley\\BOINC Setup\\",
        0,
        KEY_READ|KEY_WOW64_64KEY,
        &hKey) == ERROR_SUCCESS)
    {
        wchar_t szPath[MAX_PATH];
        DWORD dwSize = sizeof(szPath);

        if (RegQueryValueEx(
            hKey,
            L"DATADIR",
            nullptr,
            nullptr,
            (LPBYTE)&szPath,
            &dwSize) == ERROR_SUCCESS)
        {
            RegCloseKey(hKey);

            fs::path path = std::wstring(szPath);

            if (fs::exists(path)){
                return path;
            } else {
                LogPrintf("Cannot find BOINC data dir %s.", path.string());
            }
        }

        RegCloseKey(hKey);
    }

    if (fs::exists("C:\\ProgramData\\BOINC\\")){
        return "C:\\ProgramData\\BOINC\\";
    } else if(fs::exists("C:\\Documents and Settings\\All Users\\Application Data\\BOINC\\")) {
        return "C:\\Documents and Settings\\All Users\\Application Data\\BOINC\\";
    }
    #endif

    #ifdef __linux__
    // Build the list of candidate BOINC data directories.
    std::vector<fs::path> linux_candidates = {
        "/var/lib/boinc-client/",
        "/var/lib/boinc/",
    };

    char* pszHome = getenv("HOME");

    if (pszHome && strlen(pszHome) > 0) {
        linux_candidates.push_back(fs::path(pszHome) / ".var/app/edu.berkeley.BOINC/");
    }

    // Pass 1: Prefer a directory with client_state.xml (active BOINC installation).
    for (const auto& candidate : linux_candidates) {
        if (fs::exists(candidate / "client_state.xml")) {
            return candidate;
        }
    }

    // Pass 2: Fall back to any directory that exists (installed but not yet run).
    for (const auto& candidate : linux_candidates) {
        if (fs::exists(candidate)) {
            return candidate;
        }
    }
    #endif

    #ifdef __APPLE__
    if (fs::exists("/Library/Application Support/BOINC Data/")) {
        return "/Library/Application Support/BOINC Data/";
    }
    #endif

    error("%s: Cannot find BOINC data directory. You may need to manually specify in the gridcoinresearch.conf file "
          "the data directory location by using boincdatadir=<data directory location>.", __func__);

    return "";
}
