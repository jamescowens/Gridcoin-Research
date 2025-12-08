package=harfbuzz
$(package)_version=11.2.1
$(package)_download_path=https://github.com/harfbuzz/harfbuzz/releases/download/11.2.1
$(package)_file_name=$(package)-$($(package)_version).tar.xz
$(package)_sha256_hash=093714c8548a285094685f0bdc999e202d666b59eeb3df2ff921ab68b8336a49
$(package)_dependencies=

define $(package)_set_vars
#$(package)_config_opts=-DENABLE_COMMONCRYPTO=OFF
#$(package)_config_opts+=-DENABLE_GNUTLS=OFF
#$(package)_config_opts+=-DENABLE_MBEDTLS=OFF
#$(package)_config_opts+=-DENABLE_OPENSSL=OFF
#$(package)_config_opts+=-DENABLE_WINDOWS_CRYPTO=OFF
#$(package)_config_opts+=-DENABLE_BZIP2=OFF
#$(package)_config_opts+=-DENABLE_LZMA=OFF
#$(package)_config_opts+=-DENABLE_ZSTD=OFF
#$(package)_config_opts+=-DENABLE_FDOPEN=OFF
#$(package)_config_opts+=-DBUILD_TOOLS=OFF
#$(package)_config_opts+=-DBUILD_REGRESS=OFF
#$(package)_config_opts+=-DBUILD_OSSFUZZ=OFF
#$(package)_config_opts+=-DBUILD_EXAMPLES=OFF
#$(package)_config_opts+=-DBUILD_DOC=OFF
$(package)_config_opts_mingw32+=-DCMAKE_SYSTEM_IGNORE_PATH=/usr/include
endef

define $(package)_config_cmds
  mkdir ./build && $($(package)_cmake) -S . -B ./build -DBUILD_SHARED_LIBS=OFF -DCMAKE_LIBRARY_PATH=$(host_prefix)
endef

define $(package)_build_cmds
  $(MAKE) -C ./build
endef

define $(package)_stage_cmds
  $(MAKE) -C ./build DESTDIR=$($(package)_staging_dir) install -j1
endef
