package=miniupnpc
$(package)_version=2.2.2
$(package)_download_path=https://miniupnp.tuxfamily.org/files/
$(package)_file_name=$(package)-$($(package)_version).tar.gz
$(package)_sha256_hash=888fb0976ba61518276fe1eda988589c700a3f2a69d71089260d75562afd3687
$(package)_patches=dont_leak_info.patch

define $(package)_set_vars
  $(package)_config_opts+=-DUPNPC_BUILD_STATIC=ON
  $(package)_config_opts+=-DUPNPC_BUILD_SHARED=OFF
  $(package)_config_opts_mingw32+=-DCMAKE_SYSTEM_IGNORE_PATH=/usr/include
  $(package)_config_opts+=-DUPNPC_BUILD_TESTS=OFF
  $(package)_config_opts+=-DUPNPC_BUILD_SAMPLE=OFF
  $(package)_cxxflags_aarch64_linux = $(GCCFLAGS)
  $(package)_cflags_aarch64_linux = $(GCCFLAGS)
  $(package)_cxxflags_arm_linux = $(GCCFLAGS)
  $(package)_cflags_arm_linux = $(GCCFLAGS)
endef

define $(package)_preprocess_cmds
  patch -p1 < $($(package)_patch_dir)/dont_leak_info.patch
endef

define $(package)_config_cmds
  $($(package)_cmake) -S . -B .
endef

define $(package)_build_cmds
  $(MAKE)
endef

define $(package)_stage_cmds
  $(MAKE) DESTDIR=$($(package)_staging_dir) install
endef
