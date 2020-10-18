package=cmake
$(package)_version=3.18.4
$(package)_download_path=https://github.com/Kitware/CMake/releases/download/v$($(package)_version)/
$(package)_file_name=$(package)-$($(package)_version).tar.gz
$(package)_sha256_hash=597c61358e6a92ecbfad42a9b5321ddd801fc7e7eca08441307c9138382d4f77
$(package)_dependencies=zlib bzip2

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


#define $(package)_preprocess_cmds
#  sed -i.old 's/\#  ifdef _WIN32/\#  if defined _WIN32 \&\& defined ZIP_DLL/' lib/zip.h
  #&& \
  #patch -p1 < $($(package)_patch_dir)/nonrandomopentest.c.patch
#endef

define $(package)_config_cmds
   ./bootstrap --prefix=$(host_prefix)
endef

define $(package)_build_cmds
  $(MAKE)
endef

define $(package)_stage_cmds
  $(MAKE) DESTDIR=$($(package)_staging_dir) install
endef
