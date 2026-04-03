# OpenBSD build guide

This guide details how to build Gridcoin on OpenBSD. While this is not checked in CI/CD, it has been verified to work as of the 5.5.0.0 release.

## 1. Install Dependencies

Run the following commands as root (or using `doas`) to install the necessary build tools and libraries.

```ksh
# Basic build requirements and libraries
pkg_add git cmake boost curl libzip miniupnpc

# If you prefer sudo over the native doas (optional)
pkg_add sudo
````

### Note on Sudo vs. Doas

OpenBSD uses `doas` by default. If you prefer `sudo`:

1.  Ensure your user is in the `wheel` group:
    ```ksh
    # Replace 'jco' with your username
    usermod -G wheel jco
    ```
2.  Edit the sudoers file using `visudo` and find the line:
    `## Uncomment to allow members of group wheel to execute any command`

    Uncomment the following line, which should be similar to
    `%wheel ALL=(ALL) ALL`

    and save the file with `:wq!`

## 2\. Clone the Repository

```ksh
git clone [https://github.com/gridcoin-community/Gridcoin-Research.git](https://github.com/gridcoin-community/Gridcoin-Research.git)
cd Gridcoin-Research
git checkout master
```

-----

## 3\. Build Configuration

Choose **Option A** (Headless/Daemon) or **Option B** (GUI Wallet).

### Option A: Headless (Daemon only)

Use this configuration for servers or command-line only environments.

```ksh
# Configure
cmake -B build -DENABLE_GUI=off -DENABLE_TESTS=on -DCMAKE_BUILD_TYPE=RelWithDebInfo -DENABLE_PIE=on -DENABLE_UPNP=on

# Build
# Replace <# of cpus> with your core count, e.g., -j4
cmake --build build -j <# of cpus>

# Install (Optional)
doas cmake --install build
```

### Option B: GUI Wallet (Qt6)

Use this configuration for a desktop environment.

**Additional GUI Dependencies:**

```ksh
# Qt6 framework
pkg_add qt6

# Desktop Environment extras (Optional - for a full XFCE experience)
pkg_add xfce xfce-extras

# VMware helper (Optional - install only if running OpenBSD in a VMware VM)
pkg_add vmwh
```

**System Services:**
Qt6 and modern GUI applications require the message bus (dbus) to be running.

```ksh
rcctl enable messagebus
rcctl start messagebus
```

**Build & Install:**

```ksh
# Configure
# Note: Remove -DENABLE_QRENCODE=on if you do not have qrencode installed
cmake -B build -DENABLE_GUI=on -DENABLE_TESTS=on -DCMAKE_BUILD_TYPE=RelWithDebInfo -DUSE_QT6=on -DENABLE_PIE=on -DENABLE_QRENCODE=on -DENABLE_UPNP=on

# Build
cmake --build build -j <# of cpus>

# Install (Optional)
# This will install binaries and assets (icons, desktop files)
doas cmake --install build
```

## 4\. Running Gridcoin

### If you followed option A (Daemon only)

If you installed Gridcoin, you can launch from the terminal.

```sh
gridcoinresearchd
```

If you did not install, you can run directly from the build folder. Assuming you are still in the Gridcoin-Research repo directory,

```
./build/src/gridcoinresearchd
```

### If you followed option B (GUI)

If you installed Gridcoin, you can launch from the terminal or use the Desktop menu.

```sh
gridcoinresearch
```

If you did not install, you can run directly from the build folder. Assuming you are still in the Gridcoin-Research repo directory,

```
./build/src/qt/gridcoinresearch
```

