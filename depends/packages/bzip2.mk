package=bzip2
$(package)_version=1.0.8
$(package)_download_path=https://sourceware.org/pub/bzip2
$(package)_file_name=$(package)-$($(package)_version).tar.gz
$(package)_sha256_hash=ab5a03176ee106d3f0fa90e381da478ddae405918153cca248e682cd0c4a2269

define $(package)_build_cmds
  $(MAKE) -C . libbz2.a CFLAGS="$(CFLAGS) -fPIC" AR="$(AR)" RANLIB="$(RANLIB)"
endef

define $(package)_stage_cmds
  mkdir -p $($(package)_staging_dir)$(host_prefix)/include && \
  mkdir -p $($(package)_staging_dir)$(host_prefix)/lib && \
  cp bzlib.h $($(package)_staging_dir)$(host_prefix)/include && \
  cp libbz2.a $($(package)_staging_dir)$(host_prefix)/lib
endef

