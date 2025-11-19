package=pcre2
$(package)_version=10.45
$(package)_download_path=https://github.com/PCRE2Project/pcre2/releases/download/$(package)-$($(package)_version)
$(package)_file_name=$(package)-$($(package)_version).tar.bz2
$(package)_sha256_hash=21547f3516120c75597e5b30a992e27a592a31950b5140e7b8bfde3f192033c4
$(package)_dependencies=

define $(package)_set_vars
$(package)_config_opts = --enable-option-checking --disable-dependency-tracking
$(package)_config_opts += --disable-shared --enable-static --disable-docs --enable-pcre2-16
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

