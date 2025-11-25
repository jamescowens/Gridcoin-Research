# Gridcoin Build Dependencies

This document lists the package commands required to set up a build environment for Gridcoin on various operating systems.

## Linux (Native Build)

These packages are required to build the Gridcoin client to run on your local Linux machine.

### Debian / Ubuntu / Mint
```bash
sudo apt-get update
sudo apt-get install \
    build-essential libtool autotools-dev automake pkg-config bsdmainutils python3 \
    cmake git curl \
    libssl-dev libevent-dev libboost-all-dev \
    libminiupnpc-dev libqrencode-dev libzip-dev \
    qt6-base-dev qt6-tools-dev qt6-l10n-tools libqt6charts6-dev
````

### Fedora / RHEL

```bash
sudo dnf install \
    gcc-c++ libtool automake autoconf pkgconf-pkg-config python3 \
    cmake git curl \
    openssl-devel libevent-devel boost-devel \
    miniupnpc-devel qrencode-devel libzip-devel \
    qt6-qtbase-devel qt6-qttools-devel qt6-qtcharts-devel
```

### openSUSE

```bash
sudo zypper addrepo -f https://download.opensuse.org/repositories/windows:/mingw:/win32/... (select based on distro)

sudo zypper addrepo -f https://download.opensuse.org/repositories/windows:/mingw:/win64/... (select based on distro)

sudo zypper install \
    -t pattern devel_basis \
    libtool automake autoconf pkg-config python3 \
    cmake git curl \
    libopenssl-devel libevent-devel boost-devel \
    miniupnpc-devel qrencode-devel libzip-devel \
    qt6-base-devel qt6-tools-devel qt6-charts-devel
```

### Arch Linux / Manjaro

```bash
sudo pacman -S \
    base-devel python cmake git \
    boost libevent miniupnpc libzip qrencode \
    qt6-base qt6-tools qt6-charts
```

-----

## Linux (Windows Cross-Compilation)

These packages are required **in addition** to the native dependencies if you intend to build Windows binaries from a Linux host.

### Debian / Ubuntu (WSL)

```bash
# Required for the cross-compiler and NSIS installer generator
sudo apt-get install g++-mingw-w64-x86-64 nsis
```

### Fedora

```bash
sudo dnf install mingw64-gcc-c++ mingw64-nsis
```

### openSUSE

```bash
sudo zypper install mingw64-cross-gcc-c++ nsis
```

### Arch Linux

```bash
# Requires packages from AUR
paru -S mingw-w64-gcc nsis
```

-----

## macOS (Homebrew)

```bash
brew install cmake boost libevent qt@6 openssl@3 zeromq
```

-----

## BSD Variants

### FreeBSD

```bash
pkg install git cmake boost-libs qt6 libevent openssl
```

### OpenBSD

```bash
pkg_add git cmake boost qt6 libevent
```
