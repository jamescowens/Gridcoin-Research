package=xz
$(package)_version=5.2.5
$(package)_download_path=https://sourceforge.net/projects/lzmautils/files
$(package)_file_name=$(package)-$($(package)_version).tar.gz
$(package)_sha256_hash=f6f4910fd033078738bd82bfba4f49219d03b17eb0794eb91efbae419f4aba10

define $(package)_set_vars
$(package)_config_opts=--disable-shared --enable-static --disable-doc --disable-xz --disable-xzdec --disable-lzmadec --disable-lzmainfo --disable-lzma-links --disable-scripts
$(package)_config_opts += --libdir=$(host_prefix)/lib
$(package)_config_opts_linux=--with-pic
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
