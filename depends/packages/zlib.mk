package=zlib
$(package)_version=1.3.1
$(package)_download_path=https://www.zlib.net
$(package)_file_name=$(package)-$($(package)_version).tar.gz
$(package)_sha256_hash=9a93b2b7dfdac77ceba5a558a580e74667dd6fede4585b91eefb60f03b72df23

# We must define a build subdirectory so that 'cmake -S ..' correctly finds the source in the parent directory.
$(package)_build_subdir = build

define $(package)_set_vars
$(package)_config_opts=-DBUILD_SHARED_LIBS=OFF
$(package)_config_opts+=-DCMAKE_C_FLAGS="$($(package)_cflags) $($(package)_cppflags) -fpermissive -Wno-error"

ifneq ($(host_os),mingw32)
  $(package)_config_opts+=-DCMAKE_POSITION_INDEPENDENT_CODE=ON
endif

endef

# Use CMake instead of the legacy configure script
define $(package)_config_cmds
  $($(package)_cmake) -S .. -B . $($(package)_config_opts)
endef

define $(package)_build_cmds
  $(MAKE) -j$(host_nproc)
endef

define $(package)_stage_cmds
$(MAKE) DESTDIR=$($(package)_staging_dir) install && \
if [ -f $($(package)_staging_dir)$(host_prefix)/lib/libzlibstatic.a ]; then \
  cp $($(package)_staging_dir)$(host_prefix)/lib/libzlibstatic.a $($(package)_staging_dir)$(host_prefix)/lib/libz.a; \
fi
endef
