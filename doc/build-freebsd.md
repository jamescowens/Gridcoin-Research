# FreeBSD Build Guide

This guide details how to build Gridcoin on FreeBSD (14.x+).

## 1. System Preparation (First Run Only)

**Hostname Setup:**
FreeBSD requires the FQDN in the configuration. If you are setting this OS up fresh, then replace `hostname` and `domainname` with your desired names.

```sh
sudo sysrc hostname="hostname.domainname"
sudo hostname "hostname.domainname"
````

*Note: Ensure you add this hostname to `/etc/hosts` next to 127.0.0.1 and ::1 to prevent sudo delays.*

**Enable Desktop Services (VMware/XFCE):**
Required for mouse integration (`evdev`) and GUI permissions in a virtualized environment.

```sh
# Enable mouse/keyboard integration
echo "kern.evdev.rcpt_mask=6" | sudo tee -a /etc/sysctl.conf
sudo sysctl kern.evdev.rcpt_mask=6

# Enable DBus and VMware services
sudo sysrc dbus_enable="YES"
sudo sysrc hald_enable="YES"
sudo sysrc vmware_guest_dmp_enable="YES"
sudo sysrc vmware_guest_vmmemctl_enable="YES"
sudo sysrc vmware_guest_vmblock_enable="YES"
sudo sysrc vmware_guest_vmhgfs_enable="YES"
sudo sysrc vmware_guest_vmsync_enable="YES"
sudo sysrc vmware_guestd_enable="YES"
```

## 2\. Install Dependencies

Run the following commands to install the necessary build tools and libraries.

```sh
# Update package catalog
sudo pkg update

# Basic build requirements
# Note: 'boost-all' is required to ensure headers are found.
sudo pkg install git cmake boost-all libzip curl libtool autotools pkgconf miniupnpc

# Install Qt6 for the GUI Wallet
sudo pkg install qt6
```

## 3\. Clone the Repository

```sh
git clone [https://github.com/gridcoin-community/Gridcoin-Research.git](https://github.com/gridcoin-community/Gridcoin-Research.git)
cd Gridcoin-Research
git checkout master
```

-----

## 4\. Build Configuration

Choose **Option A** (Headless/Daemon)  or **Option B** (GUI Wallet).

### Option A: Headless (Daemon only)

Use this for servers or jails where no X11 is present.

```sh
cmake -B build \
-DENABLE_GUI=off \
-DENABLE_TESTS=on \
-DCMAKE_BUILD_TYPE=RelWithDebInfo \
-DENABLE_PIE=on \
-DENABLE_UPNP=on \
-DBoost_USE_DEBUG_RUNTIME=OFF

cmake --build build -j$(sysctl -n hw.ncpu)

sudo cmake --install build
```

### Option B: GUI Wallet (Qt6) - Recommended

**Configure:**
*Note: `-DBoost_USE_DEBUG_RUNTIME=OFF` is critical on FreeBSD. It forces CMake to accept the system's "Release" version of Boost even when building Gridcoin with debug symbols. You can alternatively use "Release" instead of RelWithDebInfo if you don't need the debug symbols and omit the -DBoost_USE_DEBUG_RUNTIME=OFF flag.*

```sh
cmake -B build \
-DENABLE_GUI=on \
-DENABLE_TESTS=on \
-DCMAKE_BUILD_TYPE=RelWithDebInfo \
-DUSE_QT6=on \
-DENABLE_PIE=on \
-DENABLE_UPNP=on \
-DBoost_USE_DEBUG_RUNTIME=OFF
```

**Build:**
Use `sysctl` to automatically detect core count for parallel compilation. Pay attention to memory usage. General 1 GB per core is required, so if you have a smaller amount of memory, you may want to substitute your RAM in GB - 1 GB as the number of CPUs.

```sh
cmake --build build -j$(sysctl -n hw.ncpu)
```

**Install (Optional):**

```sh
sudo cmake --install build
```

## 5\. Running Gridcoin

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
