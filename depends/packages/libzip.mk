package=libzip
$(package)_version=1.7.3
$(package)_download_path=https://libzip.org/download/
$(package)_file_name=$(package)-$($(package)_version).tar.gz
$(package)_sha256_hash=0e2276c550c5a310d4ebf3a2c3dfc43fb3b4602a072ff625842ad4f3238cb9cc
$(package)_dependencies=cmake zlib bzip2
$(package)_patches=nonrandomopentest.c.patch


define $(package)_set_vars
  $(package)_build_opts= CC="$($(package)_cc)"
  $(package)_build_opts+=CFLAGS="$($(package)_cflags) $($(package)_cppflags) -fPIC"
  $(package)_build_opts+=RANLIB="$($(package)_ranlib)"
  $(package)_build_opts+=AR="$($(package)_ar)"
  $(package)_cxxflags_aarch64_linux = $(GCCFLAGS)
  $(package)_cflags_aarch64_linux = $(GCCFLAGS)
  $(package)_cxxflags_arm_linux = $(GCCFLAGS)
  $(package)_cflags_arm_linux = $(GCCFLAGS)
endef

ifeq ($(host),i686-pc-linux-gnu)
  i686_cflag="$($(package)_cflags) $($(package)_cppflags) -fPIC -m32"
else
  i686_cflag="$($(package)_cflags) $($(package)_cppflags) -fPIC"
endif


define $(package)_preprocess_cmds
  sed -i.old 's/\#  ifdef _WIN32/\#  if defined _WIN32 \&\& defined ZIP_DLL/' lib/zip.h
  #&& \
  #patch -p1 < $($(package)_patch_dir)/nonrandomopentest.c.patch
endef

# define $(package)_config_cmds
#  $($(package)_build_opts) CFLAGS=$(i686_cflag)  ./configure --host=$(host) \
#  --prefix=$(host_prefix) --with-zlib=$(host_prefix) --with-bzip2=$(host_prefix) \
#  --with-pic --enable-static --enable-shared=no  --libdir=$($($(package)_type)_prefix)/lib
#endef

#   -DGNU_HOST=$(host) \
#   -DCMAKE_FORCE_C_COMPILER=${host}-gcc GNU) \
#   CMAKE_SYSROOT=/home/devel/rasp-pi-rootfs)
#   set(CMAKE_STAGING_PREFIX /home/devel/stage)

#set(tools /home/devel/gcc-4.7-linaro-rpi-gnueabihf)
#set(CMAKE_C_COMPILER ${tools}/bin/arm-linux-gnueabihf-gcc)
#set(CMAKE_CXX_COMPILER ${tools}/bin/arm-linux-gnueabihf-g++)

#set(CMAKE_FIND_ROOT_PATH_MODE_PROGRAM NEVER)
#set(CMAKE_FIND_ROOT_PATH_MODE_LIBRARY ONLY)
#set(CMAKE_FIND_ROOT_PATH_MODE_INCLUDE ONLY)
#set(CMAKE_FIND_ROOT_PATH_MODE_PACKAGE ONLY)

define $(package)_config_cmds
   mkdir build && \
   cd build && \
   CMAKE_SYSTEM_NAME=Linux \
   CMAKE_SYSTEM_PROCESSOR=x86_64 \
    $($(package)_build_opts) CFLAGS=$(i686_cflag) cmake .. \
   -DBUILD_SHARED_LIBS=off \
   -DCMAKE_INSTALL_PREFIX=$(host_prefix) \
   -DCMAKE_INSTALL_LIBDIR=$($($(package)_type)_prefix)/lib \
   -DENABLE_COMMONCRYPTO=OFF \
   -DENABLE_GNUTLS=OFF \
   -DENABLE_MBEDTLS=OFF
endef

define $(package)_build_cmds
  $(MAKE)
endef

define $(package)_stage_cmds
  $(MAKE) DESTDIR=$($(package)_staging_dir) install
endef
