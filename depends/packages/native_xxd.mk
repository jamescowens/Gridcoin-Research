package=native_xxd
$(package)_version=9.1.0
$(package)_download_path=https://github.com/vim/vim/archive
$(package)_file_name=v$($(package)_version).tar.gz
$(package)_sha256_hash=ddb435f6e386c53799a3025bdc5a3533beac735a0ee596cb27ada97366a1c725
$(package)_build_subdir=src/xxd

define $(package)_build_cmds
    $(MAKE)
endef

define $(package)_stage_cmds
    mkdir -p $($(package)_staging_prefix_dir)/bin && \
    cp xxd $($(package)_staging_prefix_dir)/bin/
endef
