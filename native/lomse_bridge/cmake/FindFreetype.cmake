# This module is used only when native/lomse_bridge is given a pinned
# FreeType source tree. The source tree is added by the parent project before
# Lomse calls find_package(Freetype).

if(NOT TARGET freetype)
  set(Freetype_FOUND FALSE)
  set(FREETYPE_FOUND FALSE)
  message(FATAL_ERROR
    "The pinned FreeType source must define the freetype CMake target")
endif()

set(Freetype_FOUND TRUE)
set(FREETYPE_FOUND TRUE)
set(FREETYPE_LIBRARY freetype)
set(FREETYPE_LIBRARIES freetype)
set(FREETYPE_INCLUDE_DIRS
  "${PAGE_LOMSE_FREETYPE_SOURCE_DIR}/include"
  "${PAGE_LOMSE_FREETYPE_BINARY_DIR}/include"
)

if(NOT TARGET Freetype::Freetype)
  add_library(Freetype::Freetype INTERFACE IMPORTED)
  set_target_properties(Freetype::Freetype PROPERTIES
    INTERFACE_LINK_LIBRARIES freetype
    INTERFACE_INCLUDE_DIRECTORIES
      "${PAGE_LOMSE_FREETYPE_SOURCE_DIR}/include;${PAGE_LOMSE_FREETYPE_BINARY_DIR}/include"
  )
endif()
