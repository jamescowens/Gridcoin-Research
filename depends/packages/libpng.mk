package=libpng
$(package)_version=1.6.48
$(package)_download_path=https://download.sourceforge.net/libpng
$(package)_file_name=$(package)-$($(package)_version).tar.xz
$(package)_sha256_hash=46fd06ff37db1db64c0dc288d78a3f5efd23ad9ac41561193f983e20937ece03
$(package)_dependencies=

define $(package)_set_vars
$(package)_config_opts = --enable-option-checking --disable-dependency-tracking
$(package)_config_opts += --disable-shared --enable-static --disable-docs
$(package)_config_opts +=--libdir=$($($(package)_type)_prefix)/lib
$(package)_cflags+=-fPIC
$(package)_cflags += -Wno-error=array-bounds
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
  rm lib/*.la
endef

