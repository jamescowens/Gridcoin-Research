#!/usr/bin/env bash

export LC_ALL=C

install_deps() {
    local TARGET="$1"
    local USE_QT6="$2"

    if [ -f /etc/os-release ]; then
        # The next line prevents the linter from looking into os-release and complaining about unused variables.
        # shellcheck source=/dev/null
        . /etc/os-release
        OS=$ID
    else
        echo "Error: Cannot detect OS distribution."
        return 1
    fi

    echo "Detected OS: $OS"
    echo "Installing dependencies for Target: $TARGET, Qt6: $USE_QT6"

    # --- Package Groups Definition ---
    # Initialize empty string variables for package lists
    PKGS_BASE=""
    PKGS_QT=""
    PKGS_MINGW=""

    # Helper to append to lists
    append_base() { PKGS_BASE="$PKGS_BASE $*"; }
    append_qt() { PKGS_QT="$PKGS_QT $*"; }
    append_mingw() { PKGS_MINGW="$PKGS_MINGW $*"; }

    # --- Define Packages per OS ---
    case $OS in
        debian|ubuntu|linuxmint)
            # Base Build Tools
            append_base build-essential libtool autotools-dev automake pkg-config bsdmainutils python3 cmake git curl ccache doxygen graphviz bison

            # Libraries for Native Build
            # Includes zipcmp/zipmerge/ziptool for libzip CMake config
            append_base libssl-dev libevent-dev libboost-all-dev libminiupnpc-dev libqrencode-dev libzip-dev libcurl4-openssl-dev zipcmp zipmerge ziptool

            # Qt6 Packages (Only if requested)
            # Added: libqt6svg6-dev (Fixes "Failed to find required Qt component Svg")
            # Added: libqt6core5compat6-dev (Required by CMakeLists.txt for USE_QT6)
            append_qt qt6-base-dev qt6-tools-dev qt6-l10n-tools libqt6charts6-dev libqt6svg6-dev libqt6core5compat6-dev

            # Windows Cross-Compile Tools
            append_mingw g++-mingw-w64-x86-64 nsis
            ;;

        fedora|rhel)
            append_base libstdc++-static gcc-c++ libtool automake autoconf pkgconf-pkg-config python3 cmake git curl patch perl-FindBin bison flex ccache doxygen graphviz
            append_base openssl-devel libevent-devel boost-devel miniupnpc-devel qrencode-devel libzip-devel libcurl-devel libzip-tools

            # Fedora usually packages these differently, but ensuring basics:
            append_qt qt6-qtbase-devel qt6-qttools-devel qt6-qtcharts-devel qt6-qtsvg-devel qt6-qt5compat-devel

            append_mingw mingw64-gcc-c++ mingw64-nsis xxd
            ;;

        opensuse*|sles)
            # Detect Tumbleweed vs Leap
            if [[ "$ID" == "sles" ]]; then
                echo "Error: SLES not supported automatically."
                return 1
            fi

            IS_TUMBLEWEED="false"
            if [[ "$PRETTY_NAME" == *"Tumbleweed"* ]]; then
                DISTRO_PATH="openSUSE_Tumbleweed"
                IS_TUMBLEWEED="true"
            elif [[ "$PRETTY_NAME" == *"Leap"* ]]; then
                DISTRO_PATH="15.6"
            else
                 echo "Error: Unknown openSUSE version."
                 return 1
            fi

            # Repo Logic for openSUSE (Only needed if installing MinGW)
            if [[ "$TARGET" == "all" || "$TARGET" == "win64" ]]; then
                REPO_64_URL="https://download.opensuse.org/repositories/windows:/mingw:/win64/$DISTRO_PATH/"
                REPO_64_NAME="windows_mingw_win64"
                REPO_32_URL="https://download.opensuse.org/repositories/windows:/mingw:/win32/$DISTRO_PATH/"
                REPO_32_NAME="windows_mingw_win32"

                add_repo_if_missing() {
                    local url="$1"
                    local name="$2"
                    local desc="$3"
                    if sudo zypper lr -u | grep -Fq "$url"; then
                        echo "Repository for $desc already exists (URL match)."
                    else
                        if sudo zypper lr | grep -q "$name"; then
                            echo "Warning: Repository alias '$name' exists but URL mismatch."
                        else
                            echo "Adding $desc repository: $url"
                            sudo zypper ar -f "$url" "$name"
                        fi
                    fi
                }
                add_repo_if_missing "$REPO_64_URL" "$REPO_64_NAME" "MinGW Win64"
                add_repo_if_missing "$REPO_32_URL" "$REPO_32_NAME" "MinGW Win32"
                sudo zypper --gpg-auto-import-keys refresh
            fi

            # Pattern Install
            echo "Installing devel_basis pattern..."
            sudo zypper install -y -t pattern devel_basis

            # Individual Packages
            # Base common packages
            append_base libtool automake autoconf pkg-config python3 cmake git curl ccache doxygen graphviz libzstd-devel
            append_base libopenssl-devel libevent-devel qrencode-devel libzip-devel libcurl-devel libzip-tools
            append_base miniupnpc libminiupnpc-devel

            # Boost Packages (Common)
            append_base libboost_headers-devel libboost_filesystem-devel libboost_thread-devel libboost_date_time-devel libboost_iostreams-devel libboost_serialization-devel libboost_test-devel libboost_atomic-devel libboost_regex-devel

            # Boost System Logic:
            # Leap (Boost < 1.8x) requires libboost_system-devel.
            # Tumbleweed (Boost >= 1.8x) treats system as header-only, so the package is gone.
            if [[ "$IS_TUMBLEWEED" == "false" ]]; then
                append_base libboost_system-devel
                # Leap also needs GCC 13 for C++17 support
                append_base gcc13 gcc13-c++
            fi

            # OpenSUSE Qt6 naming
            append_qt qt6-base-devel qt6-tools-devel qt6-charts-devel qt6-svg-devel qt6-qt5compat-devel qt6-linguist-devel

            append_mingw mingw64-cross-gcc-c++ nsis
            ;;

        arch|manjaro)
            # Use -Syu to upgrade ALL packages to match the new libraries we are installing.
            # Arch does not support partial upgrades; mixing old libs with new Boost is fatal.
            sudo pacman -Syu --noconfirm

            append_base base-devel python cmake git ccache doxygen graphviz
            append_base boost libevent miniupnpc libzip qrencode curl icu

            # Arch groups these well, usually base includes svg/5compat
            append_qt qt6-base qt6-tools qt6-charts qt6-svg qt6-5compat

            append_mingw mingw-w64-gcc nsis
            ;;

        *)
            echo "Error: Unsupported distribution '$OS'."
            return 1
            ;;
    esac

    # --- Determine Final Package List to Install ---
    PKGS_TO_INSTALL=""

    if [[ "$TARGET" == "all" || "$TARGET" == "native" || "$TARGET" == "depends" ]]; then
        PKGS_TO_INSTALL="$PKGS_TO_INSTALL $PKGS_BASE"
    fi

    if [[ "$USE_QT6" == "true" ]]; then
        if [[ "$TARGET" == "all" || "$TARGET" == "native" ]]; then
            PKGS_TO_INSTALL="$PKGS_TO_INSTALL $PKGS_QT"
        fi
    fi

    if [[ "$TARGET" == "all" || "$TARGET" == "win64" ]]; then
        PKGS_TO_INSTALL="$PKGS_TO_INSTALL $PKGS_MINGW"
    fi

    # Clean up leading whitespace
    PKGS_TO_INSTALL=$(echo "$PKGS_TO_INSTALL" | xargs)

    if [ -z "$PKGS_TO_INSTALL" ]; then
        echo "No packages selected for installation."
        return 0
    fi

    # --- Execute Install Command ---
    echo "Installing Packages: $PKGS_TO_INSTALL"

    case $OS in
        debian|ubuntu|linuxmint)
            sudo apt-get update
            sudo apt-get install -y $PKGS_TO_INSTALL

            # --- CRITICAL FIX: Set MinGW threading to POSIX ---
            # This fixes the "hang at end of test" issue by enabling std::thread support.
            if [[ "$TARGET" == "all" || "$TARGET" == "win64" ]]; then
                echo "Configuring MinGW-w64 threading model to POSIX..."
                if [ -f /usr/bin/x86_64-w64-mingw32-g++-posix ]; then
                    sudo update-alternatives --set x86_64-w64-mingw32-g++ /usr/bin/x86_64-w64-mingw32-g++-posix
                    sudo update-alternatives --set x86_64-w64-mingw32-gcc /usr/bin/x86_64-w64-mingw32-gcc-posix
                    echo "MinGW-w64 threading model set to POSIX."
                else
                    echo "Warning: MinGW POSIX alternative not found. Skipping threading configuration."
                fi
            fi
            ;;
        fedora|rhel)
            sudo dnf install -y $PKGS_TO_INSTALL
            ;;
        opensuse*|sles)
            sudo zypper install -y $PKGS_TO_INSTALL
            ;;
        arch|manjaro)
            sudo pacman -S --noconfirm $PKGS_TO_INSTALL
            ;;
    esac
}
