What is Gridcoin?
=================

Gridcoin is a POS-based cryptocurrency that rewards users for participating on the [BOINC](https://boinc.berkeley.edu/) network.
Gridcoin uses peer-to-peer technology to operate with no central authority - managing transactions, issuing money and contributing to scientific research are carried out collectively by the network.

For Gridcoin binaries, see the [GitHub releases page](https://github.com/gridcoin-community/Gridcoin-Research/releases). For more information, see https://gridcoin.us/.

Building Gridcoin
=================

The easiest way to build Gridcoin is with the included build script, which automatically installs dependencies for a wide range of Linux distributions and macOS:

```bash
./build_targets.sh TARGET=native
```

The script supports several targets and options:

| Target | Description |
|--------|-------------|
| `native` | Dynamic linking against system libraries (development, packaging) |
| `depends` | Static linking for portable release binaries |
| `win64` | Windows cross-compilation from Linux |
| `macos` | macOS build (from macOS host) |

Run `./build_targets.sh --help` for all options, including Qt5/Qt6 selection, ccache, build type, and more.

For manual builds and platform-specific instructions, see [doc/build.md](doc/build.md).

Development process
===================

Developers work in their own trees, then submit pull requests to the
development branch when they think their feature or bug fix is ready.

The patch will be accepted if there is broad consensus that it is a
good thing. Developers should expect to rework and resubmit patches
if they don't match the project's coding conventions (see [developer-notes.md](doc/developer-notes.md))
or are controversial.

The master branch is regularly built and tested, but is not guaranteed
to be completely stable. [Tags](https://github.com/gridcoin-community/Gridcoin-Research/tags) are regularly created to indicate new
stable release versions of Gridcoin.

Feature branches are created when there are major new features being
worked on by several people.

Branching strategy
==================

Gridcoin uses five branches to ensure stability without slowing down
the pace of the daily development activities - *development*, *testnet*,
*staging*, *master* and *hotfix*.

The *development* branch is used for day-to-day activities. It is the most
active branch and is where pull requests go by default. This branch may contain
code which is not yet stable or ready for production, so it should only be
executed on testnet to avoid disrupting fellow Gridcoiners.

When development is ready for broader testing, it is merged to *testnet* where
tagged testnet pre-releases are published. This branch is used extensively for
integration testing of consensus changes, hard fork activation, and new features
on the Gridcoin test network before any production release.

When a testnet release has been validated and a decision has been made to move
towards a production release, it is merged to *staging* as a final review step
before release.

Once staging is confirmed ready, it is merged to *master*, a tag is created,
and a release is made available to the public.

When a bug is found in a production version and an update needs to be
released quickly, the changes go into a *hotfix* branch for testing before
being merged to *master* for release. This allows for production updates without having to merge straight to
master if the staging branch is busy.

The typical release path is: *development* → *testnet* → *staging* → *master*.

Community
=========

For general questions, please visit our [Discord server](https://discord.gg/UMWUnMjN4x), [Matrix room](https://matrix.to/#/#gridcoin:matrix.org), or Libera Chat in #gridcoin-help.

License
-------

Gridcoin is released under the terms of the MIT license. See [COPYING](COPYING) or https://opensource.org/licenses/MIT for more
information.

Build Status
============

| Branch | Quality Gate | Production Builds | Compatibility | Distros |
|--------|-------------|-------------------|---------------|---------|
| Development | [![Quality Gate](https://github.com/gridcoin-community/Gridcoin-Research/actions/workflows/cmake_quality.yml/badge.svg?branch=development)](https://github.com/gridcoin-community/Gridcoin-Research/actions/workflows/cmake_quality.yml?query=branch%3Adevelopment) | [![Production Builds](https://github.com/gridcoin-community/Gridcoin-Research/actions/workflows/cmake_production.yml/badge.svg?branch=development)](https://github.com/gridcoin-community/Gridcoin-Research/actions/workflows/cmake_production.yml?query=branch%3Adevelopment) | [![Compatibility](https://github.com/gridcoin-community/Gridcoin-Research/actions/workflows/cmake_compatibility.yml/badge.svg?branch=development)](https://github.com/gridcoin-community/Gridcoin-Research/actions/workflows/cmake_compatibility.yml?query=branch%3Adevelopment) | [![Distros](https://github.com/gridcoin-community/Gridcoin-Research/actions/workflows/cmake_distros.yml/badge.svg?branch=development)](https://github.com/gridcoin-community/Gridcoin-Research/actions/workflows/cmake_distros.yml?query=branch%3Adevelopment) |
| Testnet | [![Quality Gate](https://github.com/gridcoin-community/Gridcoin-Research/actions/workflows/cmake_quality.yml/badge.svg?branch=testnet)](https://github.com/gridcoin-community/Gridcoin-Research/actions/workflows/cmake_quality.yml?query=branch%3Atestnet) | [![Production Builds](https://github.com/gridcoin-community/Gridcoin-Research/actions/workflows/cmake_production.yml/badge.svg?branch=testnet)](https://github.com/gridcoin-community/Gridcoin-Research/actions/workflows/cmake_production.yml?query=branch%3Atestnet) | [![Compatibility](https://github.com/gridcoin-community/Gridcoin-Research/actions/workflows/cmake_compatibility.yml/badge.svg?branch=testnet)](https://github.com/gridcoin-community/Gridcoin-Research/actions/workflows/cmake_compatibility.yml?query=branch%3Atestnet) | [![Distros](https://github.com/gridcoin-community/Gridcoin-Research/actions/workflows/cmake_distros.yml/badge.svg?branch=testnet)](https://github.com/gridcoin-community/Gridcoin-Research/actions/workflows/cmake_distros.yml?query=branch%3Atestnet) |
| Master | [![Quality Gate](https://github.com/gridcoin-community/Gridcoin-Research/actions/workflows/cmake_quality.yml/badge.svg?branch=master)](https://github.com/gridcoin-community/Gridcoin-Research/actions/workflows/cmake_quality.yml?query=branch%3Amaster) | [![Production Builds](https://github.com/gridcoin-community/Gridcoin-Research/actions/workflows/cmake_production.yml/badge.svg?branch=master)](https://github.com/gridcoin-community/Gridcoin-Research/actions/workflows/cmake_production.yml?query=branch%3Amaster) | [![Compatibility](https://github.com/gridcoin-community/Gridcoin-Research/actions/workflows/cmake_compatibility.yml/badge.svg?branch=master)](https://github.com/gridcoin-community/Gridcoin-Research/actions/workflows/cmake_compatibility.yml?query=branch%3Amaster) | [![Distros](https://github.com/gridcoin-community/Gridcoin-Research/actions/workflows/cmake_distros.yml/badge.svg?branch=master)](https://github.com/gridcoin-community/Gridcoin-Research/actions/workflows/cmake_distros.yml?query=branch%3Amaster) |
