package=xkeyboard-config
GCCFLAGS?=
$(package)_version=2.34
$(package)_download_path=http://www.x.org/releases/individual/data/xkeyboard-config
$(package)_file_name=$(package)-$($(package)_version).tar.bz2
$(package)_sha256_hash=b321d27686ee7e6610ffe7b56e28d5bbf60625a1f595124cd320c0caa717b8ce

define $(package)_set_vars
  $(package)_config_opts +=--libdir=$($($(package)_type)_prefix)/lib --disable-runtime-deps
  $(package)_cxxflags_aarch64_linux = $(GCCFLAGS)
  $(package)_cflags_aarch64_linux = $(GCCFLAGS)
  $(package)_cxxflags_arm_linux = $(GCCFLAGS)
  $(package)_cflags_arm_linux = $(GCCFLAGS)
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
  rm -rf lib/python*/site-packages/xcbgen/__pycache__
endef
