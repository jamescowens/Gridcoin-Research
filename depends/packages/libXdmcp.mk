package=libXdmcp
$(package)_version=1.1.5
$(package)_download_path=https://xorg.freedesktop.org/releases/individual/lib/
$(package)_file_name=$(package)-$($(package)_version).tar.xz
$(package)_sha256_hash=d8a5222828c3adab70adf69a5583f1d32eb5ece04304f7f8392b6a353aa2228c
$(package)_dependencies=xproto

define $(package)_set_vars
$(package)_config_opts=--disable-shared --enable-static --disable-docs
$(package)_config_opts+=--libdir=$($($(package)_type)_prefix)/lib
$(package)_cflags+=-fPIC
$(package)_config_env := PKG_CONFIG_PATH="$($($(package)_type)_prefix)/lib/pkgconfig:$($($(package)_type)_prefix)/share/pkgconfig"
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

