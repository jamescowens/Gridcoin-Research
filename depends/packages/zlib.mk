package=zlib
$(package)_version=1.3.1
$(package)_download_path=https://www.zlib.net
$(package)_file_name=$(package)-$($(package)_version).tar.gz
$(package)_sha256_hash=9a93b2b7dfdac77ceba5a558a580e74667dd6fede4585b91eefb60f03b72df23

# Critical: This tells depends to create a 'build' subdir and run configure from there.
# This makes '-S ..' correct because the source is in the parent dir.
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

# HACK: zlib's CMake build system ignores BUILD_SHARED_LIBS=OFF and builds/installs
# shared libraries anyway. We must delete them manually here to prevent the
# linker from preferring them over the static archive (libz.a) during the
# main Gridcoin build, which causes portability issues.
define $(package)_stage_cmds
  $(MAKE) DESTDIR=$($(package)_staging_dir) install && \
  rm -f $($(package)_staging_dir)$(host_prefix)/lib/libz.so* && \
  rm -f $($(package)_staging_dir)$(host_prefix)/lib/libz*.dylib && \
  rm -f $($(package)_staging_dir)$(host_prefix)/lib/libz*.dll && \
  if [ -f $($(package)_staging_dir)$(host_prefix)/lib/libzlibstatic.a ]; then \
    cp $($(package)_staging_dir)$(host_prefix)/lib/libzlibstatic.a $($(package)_staging_dir)$(host_prefix)/lib/libz.a; \
  fi
endef
