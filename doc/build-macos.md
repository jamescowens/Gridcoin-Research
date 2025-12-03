# Building Gridcoin for macOS

This guide describes how to build the Gridcoin macOS client (Qt6) from source. These instructions match the official build process used in our CI/CD pipelines.

## Prerequisites

1. macOS 12 (Monterey) or newer is recommended.
2. Xcode Command Line Tools: Install these by running the following in your terminal:

```
xcode-select --install
```

3. Homebrew: The standard package manager for macOS (see [https://brew.sh](https://brew.sh)). If you don't have it, install it by running the following in your terminal:

```
/bin/bash -c "$(curl -fsSL [https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh](https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh))"
```

## 1. Install Dependencies

We use Homebrew to install the required libraries (Qt6, Boost, OpenSSL, etc.) and build tools.

Open your terminal and run:

```
brew update
brew install qt boost openssl libevent miniupnpc qrencode libzip ccache cmake
```

Note: Homebrew installs Qt6 by default when you request qt.

## 2. Get the Source Code

Clone the repository and enter the directory (substitute the desired branch if not master):

```
git clone [https://github.com/gridcoin-community/Gridcoin-Research.git](https://github.com/gridcoin-community/Gridcoin-Research.git)
cd Gridcoin-Research
git checkout master
```

## 3. Configure the Build

We need to tell CMake where Homebrew installed Qt and OpenSSL. We do this dynamically using brew --prefix.
Create a build directory and configure the project by running the following in the terminal:

```
# Set paths for Homebrew libraries
QT6_PATH=$(brew --prefix qt)
OPENSSL_ROOT=$(brew --prefix openssl)

# Configure CMake
cmake -B build \
  -DCMAKE_PREFIX_PATH="$QT6_PATH" \
  -DENABLE_GUI=ON \
  -DENABLE_QRENCODE=ON \
  -DENABLE_UPNP=ON \
  -DDEFAULT_UPNP=ON \
  -DENABLE_TESTS=ON \
  -DUSE_QT6=ON \
  -DCMAKE_BUILD_TYPE=RelWithDebInfo \
  -DOPENSSL_ROOT_DIR="$OPENSSL_ROOT" \
  -DCMAKE_C_COMPILER_LAUNCHER=ccache \
  -DCMAKE_CXX_COMPILER_LAUNCHER=ccache
```

#### Build Types
 * RelWithDebInfo (Recommended): Optimized, but includes debug symbols.
 * Release: Fully optimized, smaller binaries.
 * Debug: Unoptimized, useful for development and debugging.

## 4. Compile

Start the compilation process. This will use all available CPU cores automatically. Note that Gridcoin compilationi requires about 1 GB per core when parallel compiling, so if you are limited on memory, you may want to substitute a lower number than is automatically determined by sysctl -n hw.logicalcpu.

```
cmake --build build -j $(sysctl -n hw.logicalcpu)
```

## 5. Run Tests (Optional)

It is highly recommended to run the self-tests to ensure the binary is functioning correctly.

```
ctest --test-dir build --output-on-failure
```

## 6. Run the Application

You can run the application directly from the build folder:

```
./build/src/qt/gridcoinresearch
```

## 7. Create the DMG Installer (Optional)

If you want to create a distributable disk image (.dmg), you can use CPack (included with CMake).

```
cpack -G DragNDrop --config build/CPackConfig.cmake -B release_packages
```

The resulting .dmg file will be located in the release_packages directory.
