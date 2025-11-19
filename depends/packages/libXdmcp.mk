package=libXdmcp
$(package)_version=1.1.3
$(package)_download_path=https://xorg.freedesktop.org/releases/individual/lib/
$(package)_file_name=$(package)-$($(package)_version).tar.bz2
$(package)_sha256_hash=20523b44aaa513e17c009e873b4aec712beac6496a540234e232625b215363a5

define $(package)_set_vars
$(package)_config_opts=--disable-shared --enable-static --disable-docs
$(package)_config_opts+=--libdir=$($($(package)_type)_prefix)/lib
$(package)_cflags+=-fPIC
endef

define $(package)_preprocess_cmds
  cp -f $(BASEDIR)/config.guess $(BASEDIR)/config.sub .
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

