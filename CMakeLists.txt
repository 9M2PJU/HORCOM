cmake_minimum_required(VERSION 3.25)

project(horcom
  VERSION 0.1.0
  DESCRIPTION "C++ rewrite of HORCOM by Robert Rettig"
  LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_CXX_EXTENSIONS OFF)

if(MSVC)
  add_compile_options(/W4 /WX /utf-8)
else()
  # partial aggregate initialisers lean on default member initialisers
  # on purpose (render primitives), MSVC /W4 has no such lint either.
  # No FMA contraction, the original computation order is binding and
  # a packager's -march must not change the numbers
  add_compile_options(-Wall -Wextra -Wpedantic -Werror
                      -Wno-missing-field-initializers -ffp-contract=off)
  # GCC 12, the AppImage compiler, reports false -Wrestrict hits inside
  # the libstdc++ string code (GCC bug 105651, fixed in 13)
  if(CMAKE_CXX_COMPILER_ID STREQUAL "GNU" AND CMAKE_CXX_COMPILER_VERSION VERSION_LESS 13)
    add_compile_options(-Wno-restrict)
  endif()
endif()

# nearly every GUI source and GUI test pulls in all of QtWidgets through
# main_window.hpp, the precompiled headers parse it once per target.
# MSVC only, the other compilers keep checking that each file includes
# what it uses
set(HORCOM_GUI_PCH <QtWidgets/QtWidgets> <filesystem> <functional> <memory> <optional> <string> <vector>)

add_subdirectory(src)
add_subdirectory(apps)

enable_testing()
add_subdirectory(tests)

# ===================================================================
# CPack Packaging Configuration (.deb, .rpm, tar.gz)
# ===================================================================
if(UNIX AND NOT APPLE)
  set(CPACK_PACKAGE_NAME "horcom")
  set(CPACK_PACKAGE_VENDOR "HORCOM Project")
  set(CPACK_PACKAGE_DESCRIPTION_SUMMARY "Complete desktop astrology program and chart calculator")
  set(CPACK_PACKAGE_HOMEPAGE_URL "https://github.com/horcom-rr/HORCOM")
  set(CPACK_PACKAGE_CONTACT "Dominik Schwimmbeck <https://github.com/horcom-rr/HORCOM>")
  set(CPACK_PACKAGE_VERSION_MAJOR 0)
  set(CPACK_PACKAGE_VERSION_MINOR 1)
  set(CPACK_PACKAGE_VERSION_PATCH 0)
  set(CPACK_RESOURCE_FILE_LICENSE "${CMAKE_SOURCE_DIR}/LICENSE")
  set(CPACK_RESOURCE_FILE_README "${CMAKE_SOURCE_DIR}/README.md")

  # Debian (.deb)
  set(CPACK_DEBIAN_PACKAGE_MAINTAINER "HORCOM Project <https://github.com/horcom-rr/HORCOM>")
  set(CPACK_DEBIAN_PACKAGE_SECTION "science")
  set(CPACK_DEBIAN_PACKAGE_PRIORITY "optional")
  set(CPACK_DEBIAN_PACKAGE_SHLIBDEPS OFF)
  set(CPACK_DEBIAN_PACKAGE_DEPENDS "libc6, libstdc++6, libqt6widgets6, libqt6svg6, libqt6printsupport6")

  # RPM (.rpm)
  set(CPACK_RPM_PACKAGE_LICENSE "GPL-3.0-or-later")
  set(CPACK_RPM_PACKAGE_GROUP "Applications/Engineering")
  set(CPACK_RPM_PACKAGE_AUTOREQ "yes")
  set(CPACK_RPM_PACKAGE_REQUIRES "qt6-qtbase-gui, qt6-qtsvg")

  include(CPack)
endif()

