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
    echo "  TARGET=<target>     Select build target. Options: native, depends, win64, all."
    echo "                      Default: all"
    echo "  BUILD_TYPE=<type>   Set the CMake build type. Options: Release, Debug, RelWithDebInfo."
    echo "                      Default: RelWithDebInfo"
    echo "  CLEAN_BUILD=<bool>  Force a clean build even if executables exist. Options: true, false."
    echo "                      Default: false"
    echo "  SKIP_DEPS=<bool>    Skip installing system dependencies (step 1). Options: true, false."
    echo "                      Default: false"
    echo "  USE_CCACHE=<bool>   Enable ccache compiler launcher. Options: true, false."
    echo "                      Default: false"
    echo "  USE_QT6=<bool>      Use Qt6 for Linux Native build. Options: true, false."
    echo "                      Default: true (Set to false for Qt5)"
    echo "  CC=<path>           Override C compiler for Native Linux build."
    echo "                      (e.g., CC=/usr/bin/gcc-13)."
    echo "  CXX=<path>          Override C++ compiler for Native Linux build."
    echo "                      (e.g., CXX=/usr/bin/g++-13)."
    echo "  --help, -h          Show this help message."
    echo ""
    echo "Examples:"
    echo "  ./build_targets.sh"
    echo "  ./build_targets.sh TARGET=native"
    echo "  ./build_targets.sh TARGET=win64 CLEAN_BUILD=true"
    echo "  ./build_targets.sh USE_CCACHE=true"
    echo "  ./build_targets.sh CC=clang CXX=clang++ BUILD_TYPE=Debug"
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
USE_QT6="true"
CC_OVERRIDE=""
CXX_OVERRIDE=""

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
        USE_QT6=*)
            USE_QT6="${arg#*=}"
            shift
            ;;
        PARALLEL=*)
            PARALLEL="${arg#*=}"
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
if [[ ! "$TARGET" =~ ^(native|depends|win64|all)$ ]]; then
    echo "Error: Invalid TARGET '$TARGET'. Must be one of: native, depends, win64, all."
    exit 1
fi

# Prepare specific CMake arguments for the Native Build (Target 1)
# We do NOT export these globally to prevent breaking the depends/cross-compile steps.
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

# Qt6 Logic for Native Build
if [ "$USE_QT6" = "true" ]; then
    NATIVE_QT_FLAG="-DUSE_QT6=ON"
else
    NATIVE_QT_FLAG="-DUSE_QT6=OFF"
fi

# Determine Concurrency
if [ -n "$PARALLEL" ]; then
    CORES="$PARALLEL"
else
    CORES=$(nproc)
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
echo "Native Qt6:   $USE_QT6"
if [ -n "$CC_OVERRIDE" ]; then echo "C Compiler:   $CC_OVERRIDE"; fi
if [ -n "$CXX_OVERRIDE" ]; then echo "CXX Compiler: $CXX_OVERRIDE"; fi
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
    echo "[Step 1] Installing System Dependencies (Requires Sudo)..."
    echo "----------------------------------------------------------------"

    # Check if the dependency script exists
    if [ -f "./install_dependencies.sh" ]; then
        source ./install_dependencies.sh
        # Pass TARGET and USE_QT6 to install_deps so it can selectively install packages
        install_deps "$TARGET" "$USE_QT6"
    else
        echo "Error: install_dependencies.sh not found. Cannot install dependencies."
        exit 1
    fi
fi

# ==============================================================================
# STEP 2: BUILD LINUX NATIVE (Target #1)
# ==============================================================================
TARGET1_EXE="build/src/gridcoinresearchd"

if [ "$TARGET" = "all" ] || [ "$TARGET" = "native" ]; then
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
            -DENABLE_GUI=ON \
            -DENABLE_QRENCODE=ON \
            -DUSE_DBUS=ON \
            -DENABLE_UPNP=ON \
            -DDEFAULT_UPNP=ON \
            -DENABLE_PIE=ON \
            -DENABLE_DOCS=ON \
            -DENABLE_TESTS=ON \
            $NATIVE_QT_FLAG \
            -DCMAKE_BUILD_TYPE=$BUILD_TYPE \
            $NATIVE_CMAKE_ARGS

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

if [ "$TARGET" = "all" ] || [ "$TARGET" = "depends" ]; then
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
            # CRITICAL: Remove the work/build dir to clear CMake caches for all packages
            rm -rf work/build/x86_64-pc-linux-gnu
            rm -rf work/staging/x86_64-pc-linux-gnu
        fi

        # Configure Ccache for Depends
        DEPENDS_ARGS=""
        if [ "$USE_CCACHE" = "true" ]; then
             # This tells the depends Makefile to wrap compilers with ccache
             DEPENDS_ARGS="CC_CACHE=ccache"
        fi

        make HOST=x86_64-pc-linux-gnu $DEPENDS_ARGS -j $CORES
        cd ..

        # Clean previous build
        rm -rf build_linux_depends

        # Set DEP_LIB variable required by the recipe
        DEP_LIB=$(pwd)/depends/x86_64-pc-linux-gnu/lib
        export DEP_LIB

        # Configuration from build.md "2. Linux Static Build"
        cmake -B build_linux_depends \
            --toolchain depends/x86_64-pc-linux-gnu/toolchain.cmake \
            -DENABLE_GUI=ON \
            -DUSE_QT6=ON \
            -DSTATIC_LIBS=ON \
            -DENABLE_UPNP=ON \
            -DDEFAULT_UPNP=ON \
            -DENABLE_TESTS=ON \
            -DDEP_LIB="${DEP_LIB}" \
            -DCMAKE_CXX_FLAGS="-fPIE" \
            -DCMAKE_EXE_LINKER_FLAGS="-static-libgcc -static-libstdc++ -Wl,-Bdynamic" \
            -DCMAKE_BUILD_TYPE=$BUILD_TYPE

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

if [ "$TARGET" = "all" ] || [ "$TARGET" = "win64" ]; then
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
            # CRITICAL: Remove the work/build dir to clear CMake caches
            rm -rf work/build/x86_64-w64-mingw32
            rm -rf work/staging/x86_64-w64-mingw32
        fi

        # Configure Ccache for Depends
        DEPENDS_ARGS=""
        if [ "$USE_CCACHE" = "true" ]; then
             # This tells the depends Makefile to wrap compilers with ccache
             DEPENDS_ARGS="CC_CACHE=ccache"
        fi

        make HOST=x86_64-w64-mingw32 $DEPENDS_ARGS -j $CORES
        cd ..

        # Clean previous build
        rm -rf build_win64

        # Configuration from build.md "3. Windows Cross-Compile Build"
        cmake -B build_win64 \
            --toolchain depends/x86_64-w64-mingw32/toolchain.cmake \
            -DENABLE_GUI=ON \
            -DUSE_QT6=ON \
            -DENABLE_UPNP=ON \
            -DDEFAULT_UPNP=ON \
            -DENABLE_TESTS=ON \
            -DSYSTEM_XXD=ON \
            -DCMAKE_CROSSCOMPILING_EMULATOR=/usr/bin/wine \
            -DCMAKE_EXE_LINKER_FLAGS="-static" \
            -DCMAKE_BUILD_TYPE=$BUILD_TYPE

        # Build
        cmake --build build_win64 -j $CORES

        # Test
        ctest --test-dir build_win64 -j $CORES

        echo ">>> Windows Build Successful."
    fi
fi

echo "----------------------------------------------------------------"
echo "ALL BUILDS COMPLETE"
echo "----------------------------------------------------------------"
if [ "$TARGET" = "all" ] || [ "$TARGET" = "native" ]; then echo "1. Linux Native: $TARGET1_EXE"; fi
if [ "$TARGET" = "all" ] || [ "$TARGET" = "depends" ]; then echo "2. Linux Static: $TARGET2_EXE"; fi
if [ "$TARGET" = "all" ] || [ "$TARGET" = "win64" ]; then echo "3. Windows:      $TARGET3_EXE"; fi
