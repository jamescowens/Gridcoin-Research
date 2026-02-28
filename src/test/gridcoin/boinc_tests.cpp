// Copyright (c) 2014-2021 The Gridcoin developers
// Distributed under the MIT/X11 software license, see the accompanying
// file COPYING or https://opensource.org/licenses/mit-license.php.

#include "gridcoin/boinc.h"
#include "fs.h"

#include <boost/test/unit_test.hpp>
#include <vector>

namespace {

//! Create a temporary directory structure for BOINC data dir resolution tests.
struct BoincDataDirTestSetup
{
    fs::path test_root;

    BoincDataDirTestSetup()
    {
        test_root = fs::temp_directory_path() / fs::unique_path("boinc_test_%%%%-%%%%");
        fs::create_directories(test_root);
    }

    ~BoincDataDirTestSetup()
    {
        fs::remove_all(test_root);
    }

    //! Create a candidate directory (installed but not active).
    fs::path CreateDir(const std::string& name)
    {
        fs::path dir = test_root / name;
        fs::create_directories(dir);
        return dir;
    }

    //! Create a candidate directory with client_state.xml (active installation).
    fs::path CreateActiveDir(const std::string& name)
    {
        fs::path dir = CreateDir(name);
        fsbridge::ofstream(dir / "client_state.xml");
        return dir;
    }
};

} // anonymous namespace

BOOST_AUTO_TEST_SUITE(boinc_tests)

BOOST_AUTO_TEST_CASE(it_returns_active_native_when_only_native_is_active)
{
    BoincDataDirTestSetup setup;

    fs::path native = setup.CreateActiveDir("boinc-client");

    std::vector<fs::path> candidates = {native};
    BOOST_CHECK_EQUAL(GRC::ResolveBoincDataDir(candidates), native);
}

BOOST_AUTO_TEST_CASE(it_returns_active_flatpak_when_only_flatpak_is_active)
{
    BoincDataDirTestSetup setup;

    fs::path flatpak = setup.CreateActiveDir("edu.berkeley.BOINC");

    std::vector<fs::path> candidates = {flatpak};
    BOOST_CHECK_EQUAL(GRC::ResolveBoincDataDir(candidates), flatpak);
}

BOOST_AUTO_TEST_CASE(it_prefers_active_flatpak_over_inactive_native)
{
    BoincDataDirTestSetup setup;

    fs::path native = setup.CreateDir("boinc-client");
    fs::path flatpak = setup.CreateActiveDir("edu.berkeley.BOINC");

    std::vector<fs::path> candidates = {native, flatpak};
    BOOST_CHECK_EQUAL(GRC::ResolveBoincDataDir(candidates), flatpak);
}

BOOST_AUTO_TEST_CASE(it_prefers_active_native_over_inactive_flatpak)
{
    BoincDataDirTestSetup setup;

    fs::path native = setup.CreateActiveDir("boinc-client");
    fs::path flatpak = setup.CreateDir("edu.berkeley.BOINC");

    std::vector<fs::path> candidates = {native, flatpak};
    BOOST_CHECK_EQUAL(GRC::ResolveBoincDataDir(candidates), native);
}

BOOST_AUTO_TEST_CASE(it_prefers_native_when_neither_is_active)
{
    BoincDataDirTestSetup setup;

    fs::path native = setup.CreateDir("boinc-client");
    fs::path flatpak = setup.CreateDir("edu.berkeley.BOINC");

    std::vector<fs::path> candidates = {native, flatpak};
    BOOST_CHECK_EQUAL(GRC::ResolveBoincDataDir(candidates), native);
}

BOOST_AUTO_TEST_CASE(it_returns_empty_when_no_candidates_exist)
{
    std::vector<fs::path> candidates = {"/nonexistent/boinc-client", "/nonexistent/BOINC"};
    BOOST_CHECK(GRC::ResolveBoincDataDir(candidates).empty());
}

BOOST_AUTO_TEST_CASE(it_returns_empty_for_empty_candidate_list)
{
    std::vector<fs::path> candidates;
    BOOST_CHECK(GRC::ResolveBoincDataDir(candidates).empty());
}

BOOST_AUTO_TEST_SUITE_END()
