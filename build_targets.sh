#!/usr/bin/env bash

export LC_ALL=C.UTF-8

set -e # Exit immediately if a command exits with a non-zero status.

# Error handling trap
trap 'echo "Error occurred on line $LINENO. Exiting..." >&2' ERR

# ==============================================================================
# HELPER FUNCTIONS
# ==============================================================================

print_help() {
    echo "Usage: ./build_targets.sh [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  TARGET=<target>     Select build target. Options: native, depends, win64, macos, all."
    echo "                      Default: all"
    echo "  BUILD_TYPE=<type>   Set the CMake build type. Options: Release, Debug, RelWithDebInfo."
    echo "                      Default: RelWithDebInfo"
    echo "  CLEAN_BUILD=<bool>  Force a clean build even if executables exist. Options: true, false."
    echo "                      Default: false"
    echo "  SKIP_DEPS=<bool>    Skip installing system dependencies (step 1). Options: true, false."
    echo "                      Default: false"
    echo "  USE_CCACHE=<bool>   Enable ccache compiler launcher. Options: true, false."
    echo "                      Default: false"
    echo "  WITH_GUI=<bool>     Build the GUI wallet. Options: true, false."
    echo "                      Default: true"
    echo "  USE_QT6=<bool>      Use Qt6 for Native/macOS build. Options: true, false."
    echo "                      Default: true (Set to false for Qt5)"
    echo "  PARALLEL=<int>      Specify number of build threads to use (i.e. -j X)."
    echo "                      Default: number of cpu threads reported by OS"
    echo "  QT_PATH=<path>      Override path to Qt root (e.g. /usr/local/Qt/6.6.0/macos)."
    echo "                      Bypasses Homebrew detection if set."
    echo "  EXTRA_CMAKE_ARGS    Pass additional arguments to CMake (e.g. '-DBoost_USE_STATIC_LIBS=ON')"
    echo "  CC=<path>           Override C compiler."
    echo "  CXX=<path>          Override C++ compiler."
    echo "  --help, -h          Show this help message."
    echo ""
}

# ==============================================================================
# ARGUMENT PARSING
# ==============================================================================

# Defaults
TARGET="all"
BUILD_TYPE="RelWithDebInfo"
CLEAN_BUILD="false"
SKIP_DEPS="false"
USE_CCACHE="false"
WITH_GUI="true"
USE_QT6="true"
CC_OVERRIDE=""
CXX_OVERRIDE=""
MANUAL_QT_PATH=""
EXTRA_ARGS=""

for arg in "$@"; do
    case $arg in
        TARGET=*)
            TARGET="${arg#*=}"
            shift
            ;;
        BUILD_TYPE=*)
            BUILD_TYPE="${arg#*=}"
            shift
            ;;
        CLEAN_BUILD=*)
            CLEAN_BUILD="${arg#*=}"
            shift
            ;;
        SKIP_DEPS=*)
            SKIP_DEPS="${arg#*=}"
            shift
            ;;
        USE_CCACHE=*)
            USE_CCACHE="${arg#*=}"
            shift
            ;;
        WITH_GUI=*)
            WITH_GUI="${arg#*=}"
            shift
            ;;
        USE_QT6=*)
            USE_QT6="${arg#*=}"
            shift
            ;;
        PARALLEL=*)
            PARALLEL="${arg#*=}"
            shift
            ;;
        QT_PATH=*)
            MANUAL_QT_PATH="${arg#*=}"
            shift
            ;;
        EXTRA_CMAKE_ARGS=*)
            EXTRA_ARGS="${arg#*=}"
            shift
            ;;
        CC=*)
            CC_OVERRIDE="${arg#*=}"
            shift
            ;;
        CXX=*)
            CXX_OVERRIDE="${arg#*=}"
            shift
            ;;
        --help|-h)
            print_help
            exit 0
            ;;
        *)
            echo "Error: Unknown argument '$arg'"
            print_help
            exit 1
            ;;
    esac
done

# Validate Target
if [[ ! "$TARGET" =~ ^(native|depends|win64|macos|all)$ ]]; then
    echo "Error: Invalid TARGET '$TARGET'. Must be one of: native, depends, win64, macos, all."
    exit 1
fi

# Prepare specific CMake arguments for Native/macOS
NATIVE_CMAKE_ARGS=""

if [ -n "$CC_OVERRIDE" ]; then
    NATIVE_CMAKE_ARGS="$NATIVE_CMAKE_ARGS -DCMAKE_C_COMPILER=$CC_OVERRIDE"
fi

if [ -n "$CXX_OVERRIDE" ]; then
    NATIVE_CMAKE_ARGS="$NATIVE_CMAKE_ARGS -DCMAKE_CXX_COMPILER=$CXX_OVERRIDE"
fi

if [ "$USE_CCACHE" = "true" ]; then
    NATIVE_CMAKE_ARGS="$NATIVE_CMAKE_ARGS -DCMAKE_C_COMPILER_LAUNCHER=ccache -DCMAKE_CXX_COMPILER_LAUNCHER=ccache"
fi

# Qt6 Logic
if [ "$USE_QT6" = "true" ]; then
    NATIVE_QT_FLAG="-DUSE_QT6=ON"
else
    NATIVE_QT_FLAG="-DUSE_QT6=OFF"
fi

# GUI Logic
if [ "$WITH_GUI" = "true" ]; then
    GUI_CMAKE_FLAG="-DENABLE_GUI=ON"
else
    GUI_CMAKE_FLAG="-DENABLE_GUI=OFF"
fi

# Determine Concurrency
if [ -n "$PARALLEL" ]; then
    CORES="$PARALLEL"
else
    # Cross-platform nproc detection
    if command -v nproc >/dev/null 2>&1; then
        CORES=$(nproc)
    elif command -v sysctl >/dev/null 2>&1; then
        CORES=$(sysctl -n hw.logicalcpu)
    else
        CORES=2 # Safe fallback
    fi
fi

echo "================================================================"
echo "CONFIGURATION"
echo "================================================================"
echo "Target:       $TARGET"
echo "CPU Cores:    $CORES"
echo "Build Type:   $BUILD_TYPE"
echo "Clean Build:  $CLEAN_BUILD"
echo "Skip Deps:    $SKIP_DEPS"
echo "Use Ccache:   $USE_CCACHE"
echo "With GUI:     $WITH_GUI"
echo "Qt6:          $USE_QT6"
if [ -n "$MANUAL_QT_PATH" ]; then echo "Manual Qt:    $MANUAL_QT_PATH"; fi
if [ -n "$EXTRA_ARGS" ]; then     echo "Extra Args:   $EXTRA_ARGS"; fi
if [ -n "$CC_OVERRIDE" ]; then    echo "C Compiler:   $CC_OVERRIDE"; fi
if [ -n "$CXX_OVERRIDE" ]; then   echo "CXX Compiler: $CXX_OVERRIDE"; fi
echo "================================================================"

# ==============================================================================
# STEP 1: INSTALL SYSTEM DEPENDENCIES
# ==============================================================================
if [ "$SKIP_DEPS" = "true" ]; then
    echo "----------------------------------------------------------------"
    echo "[Step 1] Skipping System Dependencies..."
    echo "----------------------------------------------------------------"
else
    echo "----------------------------------------------------------------"
    echo "[Step 1] Installing System Dependencies..."
    echo "----------------------------------------------------------------"

    # Check if the dependency script exists
    if [ -f "./install_dependencies.sh" ]; then
        source ./install_dependencies.sh
        # Pass TARGET, USE_QT6, and WITH_GUI to install_deps
        install_deps "$TARGET" "$USE_QT6" "$WITH_GUI"
    else
        echo "Error: install_dependencies.sh not found. Cannot install dependencies."
        exit 1
    fi
fi

# ==============================================================================
# STEP 2: BUILD LINUX NATIVE (Target #1)
# ==============================================================================
TARGET1_EXE="build/src/gridcoinresearchd"

# Only run if target matches AND we are on Linux
if [[ "$TARGET" == "all" || "$TARGET" == "native" ]] && [[ "$(uname -s)" == "Linux" ]]; then
    echo "----------------------------------------------------------------"
    echo "[Step 2] Building Target 1: Linux Native..."
    echo "----------------------------------------------------------------"

    if [ "$CLEAN_BUILD" = "false" ] && [ -f "$TARGET1_EXE" ]; then
        echo ">>> Executable found at $TARGET1_EXE. Skipping build."
    else
        # Clean previous build
        rm -rf build

        # Configuration from build.md "1. Linux Native Build"
        cmake -B build \
            $GUI_CMAKE_FLAG \
            -DENABLE_QRENCODE=ON \
            -DUSE_DBUS=ON \
            -DENABLE_UPNP=ON \
            -DDEFAULT_UPNP=ON \
            -DENABLE_PIE=ON \
            -DENABLE_DOCS=ON \
            -DENABLE_TESTS=ON \
            $NATIVE_QT_FLAG \
            -DCMAKE_BUILD_TYPE=$BUILD_TYPE \
            $NATIVE_CMAKE_ARGS \
            $EXTRA_ARGS

        # Build
        cmake --build build -j $CORES

        # Test
        ctest --test-dir build -j $CORES

        echo ">>> Linux Native Build Successful."
    fi
fi

# ==============================================================================
# STEP 3: BUILD LINUX STATIC DEPENDS (Target #2)
# ==============================================================================
TARGET2_EXE="build_linux_depends/src/gridcoinresearchd"

if [[ "$TARGET" == "all" || "$TARGET" == "depends" ]] && [[ "$(uname -s)" == "Linux" ]]; then
    echo "----------------------------------------------------------------"
    echo "[Step 3] Building Target 2: Linux Static (Depends System)..."
    echo "----------------------------------------------------------------"

    if [ "$CLEAN_BUILD" = "false" ] && [ -f "$TARGET2_EXE" ]; then
        echo ">>> Executable found at $TARGET2_EXE. Skipping build."
    else
        # Build Dependencies
        cd depends
        if [ "$CLEAN_BUILD" = "true" ]; then
            echo "CLEAN_BUILD=true: Cleaning depends work/build/stamps/targets for x86_64-pc-linux-gnu..."
            rm -rf x86_64-pc-linux-gnu
            rm -rf built/x86_64-pc-linux-gnu
            rm -rf work/build/x86_64-pc-linux-gnu
            rm -rf work/staging/x86_64-pc-linux-gnu
        fi

        # Configure Ccache for Depends
        DEPENDS_ARGS=""
        if [ "$USE_CCACHE" = "true" ]; then
             DEPENDS_ARGS="CC_CACHE=ccache"
        fi

        make HOST=x86_64-pc-linux-gnu $DEPENDS_ARGS -j $CORES
        cd ..

        # This is necessary because for hermeticity reasons, depends locks down search paths
        DEPENDS_NATIVE_BIN="$(pwd)/depends/x86_64-pc-linux-gnu/native/bin"

        if [ -x "$DEPENDS_NATIVE_BIN/xxd" ]; then
            echo ">>> Forcing CMake to use Native xxd: $DEPENDS_NATIVE_BIN/xxd"
            # We append this to EXTRA_ARGS so it gets passed to the cmake configuration line below
            EXTRA_ARGS="$EXTRA_ARGS -DXXD=$DEPENDS_NATIVE_BIN/xxd"
        else
            echo ">>> WARNING: Native xxd not found at $DEPENDS_NATIVE_BIN/xxd"
        fi

        # Clean previous build
        rm -rf build_linux_depends

        # Set DEP_LIB variable required by the recipe
        DEP_LIB=$(pwd)/depends/x86_64-pc-linux-gnu/lib
        export DEP_LIB

        # Configuration from build.md "2. Linux Static Build"
        cmake -B build_linux_depends \
            --toolchain depends/x86_64-pc-linux-gnu/toolchain.cmake \
            $GUI_CMAKE_FLAG \
            -DUSE_QT6=ON \
            -DSTATIC_LIBS=ON \
            -DENABLE_UPNP=ON \
            -DDEFAULT_UPNP=ON \
            -DENABLE_TESTS=ON \
            -DDEP_LIB="${DEP_LIB}" \
            -DCMAKE_CXX_FLAGS="-fPIE" \
            -DCMAKE_EXE_LINKER_FLAGS="-static-libgcc -static-libstdc++ -Wl,-Bdynamic" \
            -DCMAKE_BUILD_TYPE=$BUILD_TYPE \
            $EXTRA_ARGS

        # Build
        cmake --build build_linux_depends -j $CORES

        # Test
        ctest --test-dir build_linux_depends -j $CORES

        echo ">>> Linux Static Build Successful."
    fi
fi

# ==============================================================================
# STEP 4: BUILD WINDOWS CROSS-COMPILE (Target #3)
# ==============================================================================
TARGET3_EXE="build_win64/src/gridcoinresearchd.exe"

if [[ "$TARGET" == "all" || "$TARGET" == "win64" ]] && [[ "$(uname -s)" == "Linux" ]]; then
    echo "----------------------------------------------------------------"
    echo "[Step 4] Building Target 3: Windows Cross-Compile..."
    echo "----------------------------------------------------------------"

    if [ "$CLEAN_BUILD" = "false" ] && [ -f "$TARGET3_EXE" ]; then
        echo ">>> Executable found at $TARGET3_EXE. Skipping build."
    else
        # Build Dependencies
        cd depends
        if [ "$CLEAN_BUILD" = "true" ]; then
            echo "CLEAN_BUILD=true: Cleaning depends work/build/stamps/targets for x86_64-w64-mingw32..."
            rm -rf x86_64-w64-mingw32
            rm -rf built/x86_64-w64-mingw32
            rm -rf work/build/x86_64-w64-mingw32
            rm -rf work/staging/x86_64-w64-mingw32
        fi

        # Configure Ccache for Depends
        DEPENDS_ARGS=""
        if [ "$USE_CCACHE" = "true" ]; then
             DEPENDS_ARGS="CC_CACHE=ccache"
        fi

        make HOST=x86_64-w64-mingw32 $DEPENDS_ARGS -j $CORES
        cd ..

        # This is necessary because for hermeticity reasons, depends locks down search paths
        DEPENDS_NATIVE_BIN="$(pwd)/depends/x86_64-w64-mingw32/native/bin"

        if [ -x "$DEPENDS_NATIVE_BIN/xxd" ]; then
            echo ">>> Forcing CMake to use Native xxd: $DEPENDS_NATIVE_BIN/xxd"
            # We append this to EXTRA_ARGS so it gets passed to the cmake configuration line below
            EXTRA_ARGS="$EXTRA_ARGS -DXXD=$DEPENDS_NATIVE_BIN/xxd"
        else
            echo ">>> WARNING: Native xxd not found at $DEPENDS_NATIVE_BIN/xxd"
        fi

        # Clean previous build
        rm -rf build_win64

        # WSL Detection for Emulator Flag
        if grep -qE "(Microsoft|WSL)" /proc/version &> /dev/null; then
            echo ">>> WSL Environment detected: Using native execution for Windows binaries (No Wine)."
            CROSS_EMULATOR_FLAG=""
        else
            CROSS_EMULATOR_FLAG="-DCMAKE_CROSSCOMPILING_EMULATOR=/usr/bin/wine"
        fi

        # Configuration from build.md "3. Windows Cross-Compile Build"
        cmake -B build_win64 \
            --toolchain depends/x86_64-w64-mingw32/toolchain.cmake \
            $GUI_CMAKE_FLAG \
            -DUSE_QT6=ON \
            -DENABLE_UPNP=ON \
            -DDEFAULT_UPNP=ON \
            -DENABLE_TESTS=ON \
            -DSYSTEM_XXD=ON \
            $CROSS_EMULATOR_FLAG \
            -DCMAKE_EXE_LINKER_FLAGS="-static" \
            -DCMAKE_BUILD_TYPE=$BUILD_TYPE \
            $EXTRA_ARGS

        # Build
        cmake --build build_win64 -j $CORES

        # Test
        ctest --test-dir build_win64 -j $CORES

        echo ">>> Windows Build Successful."
    fi
fi

# ==============================================================================
# STEP 5: BUILD macOS NATIVE (Target #4)
# ==============================================================================
if [[ "$WITH_GUI" == "true" ]]; then
    TARGET4_EXE="build_macos/src/qt/gridcoinresearch.app/Contents/MacOS/gridcoinresearch"
else
    TARGET4_EXE="build_macos/src/gridcoinresearchd"
fi

if [[ "$TARGET" == "all" || "$TARGET" == "macos" ]] && [[ "$(uname -s)" == "Darwin" ]]; then
    echo "----------------------------------------------------------------"
    echo "[Step 5] Building Target 4: macOS Native..."
    echo "----------------------------------------------------------------"

    if [ "$CLEAN_BUILD" = "false" ] && [ -f "$TARGET4_EXE" ]; then
        echo ">>> Executable found at $TARGET4_EXE. Skipping build."
    else
        # Clean previous build
        rm -rf build_macos

        OPENSSL_ROOT=$(brew --prefix openssl)
        # Fix for missing icudata on macOS (ICU is keg-only)
        ICU_PREFIX=$(brew --prefix icu4c)

        # QT PATH SELECTION LOGIC
        # We only need to check for Qt if we are actually building the GUI
        if [[ "$WITH_GUI" == "true" ]]; then
            if [ -n "$MANUAL_QT_PATH" ]; then
                echo "Using Manual Qt Path: $MANUAL_QT_PATH"
                QT_PREFIX_PATH="$MANUAL_QT_PATH"
            else
                # Default Homebrew Logic
                if [ "$USE_QT6" = "true" ]; then
                     QT_FORMULA="qt"
                else
                     QT_FORMULA="qt@5"
                fi

                echo "Checking for Homebrew Qt ($QT_FORMULA)..."

                if ! QT_PREFIX_PATH=$(brew --prefix "$QT_FORMULA" 2>/dev/null); then
                     echo "Error: brew --prefix $QT_FORMULA failed. Installation broken or missing."
                     echo "Check your Homebrew install or use WITH_GUI=false if you only want the daemon."
                     exit 1
                fi
            fi
            echo "Final Qt Path: $QT_PREFIX_PATH"
        else
            echo "GUI disabled: Skipping Qt detection."
            # Set to empty or don't set CMAKE_PREFIX_PATH for Qt
            QT_PREFIX_PATH=""
        fi

        echo "Detected OpenSSL Path: $OPENSSL_ROOT"
        echo "Detected ICU Path: $ICU_PREFIX"

        # Configuration from build.md / cmake_production.yml
        # Note: We pass QT_PREFIX_PATH only if it was set
        if [ -n "$QT_PREFIX_PATH" ]; then
             PREFIX_PATHS="$QT_PREFIX_PATH;$ICU_PREFIX"
        else
             PREFIX_PATHS="$ICU_PREFIX"
        fi

        cmake -B build_macos \
            -DCMAKE_PREFIX_PATH="$PREFIX_PATHS" \
            $GUI_CMAKE_FLAG \
            -DENABLE_QRENCODE=ON \
            -DENABLE_UPNP=ON \
            -DDEFAULT_UPNP=ON \
            -DENABLE_TESTS=ON \
            -DENABLE_DOCS=OFF \
            $NATIVE_QT_FLAG \
            -DCMAKE_BUILD_TYPE=$BUILD_TYPE \
            -DOPENSSL_ROOT_DIR="$OPENSSL_ROOT" \
            $NATIVE_CMAKE_ARGS \
            $EXTRA_ARGS

        # Build
        cmake --build build_macos -j $CORES

        # Test
        ctest --test-dir build_macos -j $CORES

        echo ">>> macOS Build Successful."
    fi
fi

echo "----------------------------------------------------------------"
echo "ALL BUILDS COMPLETE"
echo "----------------------------------------------------------------"
if [[ "$(uname -s)" == "Linux" ]]; then
    if [[ "$TARGET" == "all" || "$TARGET" == "native" ]]; then echo "1. Linux Native: $TARGET1_EXE"; fi
    if [[ "$TARGET" == "all" || "$TARGET" == "depends" ]]; then echo "2. Linux Static: $TARGET2_EXE"; fi
    if [[ "$TARGET" == "all" || "$TARGET" == "win64" ]]; then echo "3. Windows:      $TARGET3_EXE"; fi
fi
if [[ "$(uname -s)" == "Darwin" ]]; then
    if [[ "$TARGET" == "all" || "$TARGET" == "macos" ]]; then echo "4. macOS Native: $TARGET4_EXE"; fi
fi
