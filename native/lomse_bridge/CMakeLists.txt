cmake_minimum_required(VERSION 3.22)

project(page_lomse_bridge LANGUAGES C CXX)

set(LOMSE_SOURCE_DIR "" CACHE PATH "Pinned Lomse source directory")
if(NOT EXISTS "${LOMSE_SOURCE_DIR}/CMakeLists.txt")
  message(FATAL_ERROR "LOMSE_SOURCE_DIR must point to a Lomse source tree")
endif()

set(PAGE_LOMSE_FREETYPE_SOURCE_DIR "" CACHE PATH
  "Pinned FreeType source directory for cross builds")
option(PAGE_LOMSE_STATIC_LOMSE
  "Link Lomse into page_lomse_bridge instead of shipping a second shared library"
  OFF)

option(PAGE_LOMSE_BUILD_SMOKE "Build the native bridge smoke executable" OFF)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_POSITION_INDEPENDENT_CODE ON)

# Lomse is a dependency of the bridge, not part of the public ABI. Keep its
# own tests/examples disabled for this target. FreeType is passed by the
# caller because Android needs a cross-compiled instance.
set(LOMSE_BUILD_TESTS OFF CACHE BOOL "" FORCE)
set(LOMSE_RUN_TESTS OFF CACHE BOOL "" FORCE)
set(LOMSE_BUILD_EXAMPLE OFF CACHE BOOL "" FORCE)
set(LOMSE_BUILD_SHARED_LIB ON CACHE BOOL "" FORCE)
set(LOMSE_BUILD_STATIC_LIB OFF CACHE BOOL "" FORCE)
set(LOMSE_ENABLE_FONTCONFIG OFF CACHE BOOL "" FORCE)
set(LOMSE_ENABLE_PNG OFF CACHE BOOL "" FORCE)
set(LOMSE_DOWNLOAD_BRAVURA_FONT OFF CACHE BOOL "" FORCE)
set(LOMSE_INSTALL_BRAVURA_FONT OFF CACHE BOOL "" FORCE)

# Android does not provide a usable FindFreetype package for this target. Build
# the pinned FreeType source as a static target first, then expose it through a
# small local FindFreetype module when Lomse runs its own dependency checks.
set(PAGE_LOMSE_FREETYPE_TARGET "")
if(PAGE_LOMSE_FREETYPE_SOURCE_DIR)
  if(NOT EXISTS "${PAGE_LOMSE_FREETYPE_SOURCE_DIR}/CMakeLists.txt")
    message(FATAL_ERROR
      "PAGE_LOMSE_FREETYPE_SOURCE_DIR must point to a FreeType source tree")
  endif()

  set(BUILD_SHARED_LIBS OFF CACHE BOOL "" FORCE)
  set(FT_DISABLE_ZLIB ON CACHE BOOL "" FORCE)
  set(FT_DISABLE_BZIP2 ON CACHE BOOL "" FORCE)
  set(FT_DISABLE_PNG ON CACHE BOOL "" FORCE)
  set(FT_DISABLE_HARFBUZZ ON CACHE BOOL "" FORCE)
  set(FT_DISABLE_BROTLI ON CACHE BOOL "" FORCE)
  set(PAGE_LOMSE_FREETYPE_BINARY_DIR
    "${CMAKE_CURRENT_BINARY_DIR}/freetype" CACHE PATH "" FORCE)

  add_subdirectory(
    "${PAGE_LOMSE_FREETYPE_SOURCE_DIR}"
    "${PAGE_LOMSE_FREETYPE_BINARY_DIR}"
    EXCLUDE_FROM_ALL
  )
  if(NOT TARGET freetype)
    message(FATAL_ERROR "The pinned FreeType source did not define target freetype")
  endif()
  set(PAGE_LOMSE_FREETYPE_TARGET freetype)
  list(PREPEND CMAKE_MODULE_PATH "${CMAKE_CURRENT_SOURCE_DIR}/cmake")
endif()

# The Lomse subdirectory keeps dependency variables in its own CMake scope.
# Resolve FreeType here too so the bridge translation unit can include the
# public Lomse font types on both macOS and Android.
find_package(Freetype REQUIRED)

if(PAGE_LOMSE_STATIC_LOMSE)
  set(LOMSE_BUILD_STATIC_LIB ON CACHE BOOL "" FORCE)
  set(LOMSE_BUILD_SHARED_LIB OFF CACHE BOOL "" FORCE)
  set(PAGE_LOMSE_LOMSE_TARGET lomse)
else()
  set(LOMSE_BUILD_STATIC_LIB OFF CACHE BOOL "" FORCE)
  set(LOMSE_BUILD_SHARED_LIB ON CACHE BOOL "" FORCE)
  set(PAGE_LOMSE_LOMSE_TARGET lomse-shared)
endif()

add_subdirectory(
  "${LOMSE_SOURCE_DIR}"
  "${CMAKE_CURRENT_BINARY_DIR}/lomse"
  EXCLUDE_FROM_ALL
)

add_library(page_lomse_bridge SHARED src/page_lomse_bridge.cpp)
target_include_directories(page_lomse_bridge
  PUBLIC include
  PRIVATE
    "${LOMSE_SOURCE_DIR}/include"
    "${LOMSE_SOURCE_DIR}/src/agg/include"
    "${LOMSE_SOURCE_DIR}/src/agg/font_freetype"
    "${LOMSE_SOURCE_DIR}/packages/utfcpp"
    "${LOMSE_SOURCE_DIR}/packages/pugixml"
    "${LOMSE_SOURCE_DIR}/packages/minizip"
    "${CMAKE_CURRENT_BINARY_DIR}/lomse"
    ${FREETYPE_INCLUDE_DIRS}
)
target_compile_features(page_lomse_bridge PRIVATE cxx_std_17)
if(NOT TARGET ${PAGE_LOMSE_LOMSE_TARGET})
  message(FATAL_ERROR
    "Expected Lomse target '${PAGE_LOMSE_LOMSE_TARGET}' was not created")
endif()
target_link_libraries(page_lomse_bridge PRIVATE ${PAGE_LOMSE_LOMSE_TARGET})
if(PAGE_LOMSE_FREETYPE_TARGET)
  target_link_libraries(page_lomse_bridge PRIVATE ${PAGE_LOMSE_FREETYPE_TARGET})
endif()
set_target_properties(page_lomse_bridge PROPERTIES OUTPUT_NAME "page_lomse_bridge")

if(PAGE_LOMSE_BUILD_SMOKE)
  add_executable(page_lomse_bridge_smoke tests/page_lomse_bridge_smoke.cpp)
  target_include_directories(page_lomse_bridge_smoke PRIVATE include)
  target_link_libraries(page_lomse_bridge_smoke PRIVATE page_lomse_bridge)
  add_dependencies(page_lomse_bridge_smoke page_lomse_bridge)
  if(APPLE OR UNIX)
    set_target_properties(page_lomse_bridge_smoke PROPERTIES
      BUILD_RPATH "$ORIGIN;${CMAKE_CURRENT_BINARY_DIR}"
    )
  endif()
endif()
