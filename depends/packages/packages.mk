packages:=boost openssl curl zlib libzip
native_packages := native_ccache

qt_packages = qrencode

qt_linux_packages:=qt expat libxcb xcb_proto libXau xproto freetype fontconfig libxkbcommon libxcb_util libxcb_util_cursor libxcb_util_render libxcb_util_keysyms libxcb_util_image libxcb_util_wm util-macros xkeyboard-config libevent libpng harfbuzz pcre2
qt_darwin_packages=qt
qt_mingw32_packages=qt
ifneq ($(host),$(build))
qt_native_packages := native_qt
endif

upnp_packages=miniupnpc

darwin_native_packages = native_ds_store native_mac_alias

ifneq ($(build_os),darwin)
darwin_native_packages += native_libdmg-hfsplus
endif
