package=libxcb
GCCFLAGS?=
$(package)_version=1.17.0
$(package)_download_path=https://xcb.freedesktop.org/dist
$(package)_file_name=$(package)-$($(package)_version).tar.xz
$(package)_sha256_hash=599ebf9996710fea71622e6e184f3a8ad5b43d0e5fa8c4e407123c88a59a6d55
$(package)_dependencies=xcb_proto libXau util-macros

define $(package)_set_vars
$(package)_config_opts=--disable-shared --enable-static --disable-devel-docs --without-doxygen --without-launchd
$(package)_config_opts += --disable-dependency-tracking --enable-option-checking
# Disable unneeded extensions.
# More info is available from: https://doc.qt.io/qt-5.15/linux-requirements.html
$(package)_config_opts += --disable-composite --disable-damage --disable-dpms
$(package)_config_opts += --disable-dri2 --disable-dri3 --disable-glx
$(package)_config_opts += --disable-present --disable-record --disable-resource
$(package)_config_opts += --disable-screensaver --disable-xevie --disable-xfree86-dri
$(package)_config_opts += --disable-xprint --disable-selinux
$(package)_config_opts += --disable-xtest --disable-xv --disable-xvmc
$(package)_config_opts +=--libdir=$($($(package)_type)_prefix)/lib
$(package)_cflags+=-fPIC
endef

define $(package)_preprocess_cmds
  sed "s/pthread-stubs//" -i configure
endef

define $(package)_config_cmds
  $($(package)_autoconf)
endef

define $(package)_build_cmds
  $(MAKE)
endef

define $(package)_stage_cmds
  $(MAKE) DESTDIR=$($(package)_staging_dir) install
endef

define $(package)_postprocess_cmds
  rm -rf share lib/*.la
endef
