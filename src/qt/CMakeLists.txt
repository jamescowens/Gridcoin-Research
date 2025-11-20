# Translations
# ============
add_subdirectory(locale)

# Cleanup: Remove stale Qt MOC files
# ==================================
# Autotools (and older build methods) generate .moc and moc_*.cpp files
# directly in the source tree. These conflict with CMake's AUTOMOC.
file(GLOB_RECURSE STALE_MOC_FILES
    "${CMAKE_CURRENT_SOURCE_DIR}/*.moc"
    "${CMAKE_CURRENT_SOURCE_DIR}/moc_*.cpp"
)

if(STALE_MOC_FILES)
    message(STATUS "Detected stale Qt MOC files in source tree. Cleaning up...")
    foreach(STALE_FILE ${STALE_MOC_FILES})
        message(STATUS "  Removing: ${STALE_FILE}")
        file(REMOVE "${STALE_FILE}")
    endforeach()
endif()

# libgridcoinqt
# =============

add_library(gridcoinqt STATIC
    aboutdialog.cpp
    addressbookpage.cpp
    addresstablemodel.cpp
    askpassphrasedialog.cpp
    bantablemodel.cpp
    bitcoinaddressvalidator.cpp
    bitcoinamountfield.cpp
    bitcoingui.cpp
    bitcoinunits.cpp
    clicklabel.cpp
    clientmodel.cpp
    coincontroldialog.cpp
    coincontroltreewidget.cpp
    consolidateunspentdialog.cpp
    consolidateunspentwizard.cpp
    consolidateunspentwizardselectdestinationpage.cpp
    consolidateunspentwizardselectinputspage.cpp
    consolidateunspentwizardsendpage.cpp
    csvmodelwriter.cpp
    decoration.cpp
    diagnosticsdialog.cpp
    editaddressdialog.cpp
    editsidestakedialog.cpp
    favoritespage.cpp
    guiutil.cpp
    intro.cpp
    monitoreddatamapper.cpp
    mrcmodel.cpp
    mrcrequestpage.cpp
    noresult.cpp
    notificator.cpp
    optionsdialog.cpp
    optionsmodel.cpp
    overviewpage.cpp
    peertablemodel.cpp
    qtipcserver.cpp
    qvalidatedlineedit.cpp
    qvaluecombobox.cpp
    receivecoinspage.cpp
    researcher/projecttablemodel.cpp
    researcher/researchermodel.cpp
    researcher/researcherwizard.cpp
    researcher/researcherwizardauthpage.cpp
    researcher/researcherwizardbeaconpage.cpp
    researcher/researcherwizardemailpage.cpp
    researcher/researcherwizardnoncruncherpage.cpp
    researcher/researcherwizardmodedetailpage.cpp
    researcher/researcherwizardmodepage.cpp
    researcher/researcherwizardpoolpage.cpp
    researcher/researcherwizardpoolsummarypage.cpp
    researcher/researcherwizardprojectspage.cpp
    researcher/researcherwizardsummarypage.cpp
    rpcconsole.cpp
    sendcoinsdialog.cpp
    sendcoinsentry.cpp
    sidestaketablemodel.cpp
    signverifymessagedialog.cpp
    trafficgraphwidget.cpp
    transactiondesc.cpp
    transactiondescdialog.cpp
    transactionfilterproxy.cpp
    transactionrecord.cpp
    transactiontablemodel.cpp
    transactionview.cpp
    updatedialog.cpp
    upgradeqt.cpp
    voting/additionalfieldstableview.cpp
    voting/additionalfieldstablemodel.cpp
    voting/poll_types.cpp
    voting/pollcard.cpp
    voting/pollcardview.cpp
    voting/polldetails.cpp
    voting/pollresultchoiceitem.cpp
    voting/pollresultdialog.cpp
    voting/polltab.cpp
    voting/polltablemodel.cpp
    voting/pollwizard.cpp
    voting/pollwizarddetailspage.cpp
    voting/pollwizardprojectpage.cpp
    voting/pollwizardsummarypage.cpp
    voting/pollwizardtypepage.cpp
    voting/votewizard.cpp
    voting/votewizardballotpage.cpp
    voting/votewizardsummarypage.cpp
    voting/votingmodel.cpp
    voting/votingpage.cpp
    walletmodel.cpp
    winshutdownmonitor.cpp

    bitcoin.qrc
    bitcoin_locale.qrc
)

if(WIN32)
    target_sources(gridcoinqt PRIVATE res/gridcoinresearch.rc)
    set_source_files_properties(res/gridcoinresearch.rc PROPERTIES
        COMPILE_DEFINITIONS WINDRES_PREPROC
    )
elseif(APPLE)
    target_sources(gridcoinqt PRIVATE
        macdockiconhandler.mm
        macnotificationhandler.mm
        macos_appnap.mm
    )
endif()

set_target_properties(gridcoinqt PROPERTIES
    AUTOMOC ON
    AUTORCC ON
    AUTOUIC ON

    AUTOUIC_SEARCH_PATHS "${CMAKE_SOURCE_DIR}/src;${CMAKE_SOURCE_DIR}/src/qt/forms"
)

# These files include 'node/ui_interface.cpp', which AutoUIC tries to process
set_source_files_properties(
    bitcoin.cpp
    clientmodel.cpp
    mrcmodel.cpp
    qtipcserver.cpp
    researcher/researchermodel.cpp
    sidestaketablemodel.cpp
    transactiondesc.cpp
    transactiontablemodel.cpp
    voting/votingmodel.cpp
    walletmodel.cpp
    PROPERTIES
        SKIP_AUTOUIC ON
)

# Libraries to link
# =================

target_link_libraries(gridcoinqt PUBLIC
    ${QT}::Core
    ${QT}::Concurrent
    ${QT}::Gui
    ${QT}::Network
    ${QT}::Widgets
    ${QT}::Svg
    gridcoin_util
)

if(USE_QT6)
    target_link_libraries(gridcoinqt PUBLIC ${QT}::Core5Compat)
endif()
if(USE_DBUS)
    target_link_libraries(gridcoinqt PUBLIC ${QT}::DBus)
endif()

if(APPLE)
    target_link_libraries(gridcoinqt PUBLIC
        "-framework Foundation"
        "-framework ApplicationServices"
        "-framework AppKit"
    )
elseif(WIN32)
    target_link_libraries(gridcoinqt PUBLIC shlwapi)
endif()

target_compile_definitions(gridcoinqt PUBLIC HAVE_CONFIG_H)
target_compile_definitions(gridcoinqt PUBLIC QT_DISABLE_DEPRECATED_UP_TO=0x050F00)

if(ENABLE_UPNP)
    if(DEFAULT_UPNP)
        target_compile_definitions(gridcoinqt PRIVATE USE_UPNP=1)
    else()
        target_compile_definitions(gridcoinqt PRIVATE USE_UPNP=0)
    endif()
endif()

add_dependencies(gridcoinqt gridcoinqt_l10n)


# Application
# ===========

add_executable(gridcoinresearch bitcoin.cpp)

set(MACOSX_BUNDLE_RESOURCE_FILES res/icons/gridcoin.icns)
if(APPLE)
    target_sources(gridcoinresearch PRIVATE ${MACOSX_BUNDLE_RESOURCE_FILES})
endif()

target_link_libraries(gridcoinresearch PRIVATE
    ${RUNTIME_LIBS}
    ${QT}::Widgets
    CURL::libcurl
    gridcoin_util
    gridcoinqt
)
if(UNIX AND NOT APPLE AND DEFINED DEP_LIB)
    # 1. The "Imposter" Math Target (This solves the -lm linker error where the linker looks for the math lib in the wrong place.)
    add_library(m SHARED IMPORTED GLOBAL)
    set_target_properties(m PROPERTIES IMPORTED_LOCATION "/lib64/libm.so.6")

    target_link_libraries(gridcoinresearch PRIVATE m)

    # 2. THE AUTOMATED MANUAL FIX
    # Define the libraries as a simple list first
    set(MY_LIBS_LIST
        "${DEP_LIB}/libfreetype.a"
        "${DEP_LIB}/libfontconfig.a"
        "${DEP_LIB}/libexpat.a"
        "${DEP_LIB}/libxcb-util.a"
    )

    # Flatten the list into a space-separated string explicitly
    string(REPLACE ";" " " MANUAL_STATIC_FIX "${MY_LIBS_LIST}")

    # Override the linker rule
    set(CMAKE_CXX_LINK_EXECUTABLE
        "<CMAKE_CXX_COMPILER> <FLAGS> <CMAKE_CXX_LINK_FLAGS> <LINK_FLAGS> <OBJECTS> -o <TARGET> <LINK_LIBRARIES> ${MANUAL_STATIC_FIX}"
    )
endif()

set_target_properties(gridcoinresearch PROPERTIES
    WIN32_EXECUTABLE TRUE
    MACOSX_BUNDLE TRUE
    MACOSX_BUNDLE_INFO_PLIST "${CMAKE_SOURCE_DIR}/share/qt/Info.plist.cmake.in"
    RESOURCE ${MACOSX_BUNDLE_RESOURCE_FILES}
)

if(UNIX AND NOT APPLE)
    include(GNUInstallDirs)
    install(TARGETS gridcoinresearch
        DESTINATION "${CMAKE_INSTALL_BINDIR}"
    )
    install(DIRECTORY "${CMAKE_SOURCE_DIR}/share/icons"
        DESTINATION "${CMAKE_INSTALL_DATADIR}"
    )
    install(FILES "${CMAKE_SOURCE_DIR}/contrib/gridcoinresearch.desktop"
        DESTINATION "${CMAKE_INSTALL_DATADIR}/applications"
    )
    install(FILES "${CMAKE_SOURCE_DIR}/doc/gridcoinresearch.1"
        DESTINATION "${CMAKE_INSTALL_MANDIR}/man1"
    )
endif()

if(WIN32)
    target_link_libraries(gridcoinresearch PRIVATE
        ws2_32
        wsock32
        wldap32
        crypt32
        bcrypt
        shlwapi
        iphlpapi
    )
endif()

# Tests
# =====

if(ENABLE_TESTS)
    add_subdirectory(test)
endif()
