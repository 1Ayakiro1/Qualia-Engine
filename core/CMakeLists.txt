cmake_minimum_required(VERSION 3.21)
project(bci_engine_core VERSION 0.1.0 LANGUAGES CXX)

# Tests are built explicitly by scripts/build_core.sh (standalone builds);
# as a Flutter subproject the default stays OFF to keep app builds lean.
option(BCI_BUILD_TESTS "Build BCI core tests (Catch2)" OFF)
option(BCI_FETCH_DEPS "Fetch missing test dependencies from the network" ON)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_CXX_EXTENSIONS OFF)
set(CMAKE_POSITION_INDEPENDENT_CODE ON)

# ---------------------------------------------------------------- core library
set(BCI_CORE_SOURCES
  src/version.cpp
  src/engine.cpp
  src/modules.cpp
  src/fft.cpp
  src/signal_v2.cpp
  src/c_api.cpp
)

add_library(bci_engine_core SHARED ${BCI_CORE_SOURCES})

target_include_directories(bci_engine_core
  PUBLIC
    ${CMAKE_CURRENT_SOURCE_DIR}/include
  PRIVATE
    ${CMAKE_CURRENT_SOURCE_DIR}/src
)

target_compile_definitions(bci_engine_core PRIVATE BCI_BUILD_CORE_DLL=1)

# Strict warnings for our own code.
if(MSVC)
  target_compile_options(bci_engine_core PRIVATE /W4 /permissive-)
else()
  target_compile_options(bci_engine_core PRIVATE -Wall -Wextra -Wpedantic -Werror)
  target_compile_options(bci_engine_core PRIVATE $<$<CONFIG:Release>:-O2>)
endif()

set_target_properties(bci_engine_core PROPERTIES
  OUTPUT_NAME bci_engine_core
  VERSION ${PROJECT_VERSION}
  SOVERSION ${PROJECT_VERSION_MAJOR}
  WINDOWS_EXPORT_ALL_SYMBOLS ON
  C_VISIBILITY_PRESET hidden
  CXX_VISIBILITY_PRESET hidden
)

# ---------------------------------------------------------------- tests
if(BCI_BUILD_TESTS)
  set(CATCH2_DIR "${CMAKE_BINARY_DIR}/thirdparty/catch2-v2.13.10")
  set(BCI_CATCH2_HEADER "${CATCH2_DIR}/catch.hpp" CACHE FILEPATH "Pinned Catch2 v2.13.10 single header (may be supplied offline)")
  set(CATCH2_SHA256 "3725c0f0a75f376a5005dde31ead0feb8f7da7507644c201b814443de8355170")
  set(CATCH2_VALID OFF)
  if(EXISTS "${BCI_CATCH2_HEADER}")
    file(SHA256 "${BCI_CATCH2_HEADER}" CATCH2_ACTUAL)
    if(CATCH2_ACTUAL STREQUAL CATCH2_SHA256)
      set(CATCH2_VALID ON)
    endif()
  endif()
  if(NOT CATCH2_VALID AND BCI_FETCH_DEPS)
    set(CATCH2_DOWNLOAD "${CATCH2_DIR}/catch.hpp.download")
    file(MAKE_DIRECTORY "${CATCH2_DIR}")
    file(DOWNLOAD
      "https://github.com/catchorg/Catch2/releases/download/v2.13.10/catch.hpp"
      "${CATCH2_DOWNLOAD}" STATUS CATCH_DL TIMEOUT 60 TLS_VERIFY ON)
    list(GET CATCH_DL 0 CATCH_DL_CODE)
    if(CATCH_DL_CODE EQUAL 0)
      file(SHA256 "${CATCH2_DOWNLOAD}" CATCH2_ACTUAL)
      if(CATCH2_ACTUAL STREQUAL CATCH2_SHA256)
        set(BCI_CATCH2_HEADER "${CATCH2_DIR}/catch.hpp" CACHE FILEPATH "Pinned Catch2 header" FORCE)
        file(RENAME "${CATCH2_DOWNLOAD}" "${BCI_CATCH2_HEADER}")
        set(CATCH2_VALID ON)
      endif()
    endif()
  endif()
  if(NOT CATCH2_VALID)
    message(FATAL_ERROR "BCI_BUILD_TESTS requires verified Catch2 v2.13.10. Download failed/mismatched or fetching is disabled; supply -DBCI_CATCH2_HEADER=/path/to/catch.hpp. Expected SHA256 ${CATCH2_SHA256}")
  endif()
  get_filename_component(CATCH2_INCLUDE "${BCI_CATCH2_HEADER}" DIRECTORY)
  enable_testing()
  add_executable(bci_core_tests tests/test_core.cpp tests/test_blocks.cpp)
  target_include_directories(bci_core_tests PRIVATE "${CATCH2_INCLUDE}" "${CMAKE_CURRENT_SOURCE_DIR}/src")
  target_link_libraries(bci_core_tests PRIVATE bci_engine_core)
  if(MSVC)
    target_compile_options(bci_core_tests PRIVATE /W4)
  else()
    target_compile_options(bci_core_tests PRIVATE -Wall -Wextra -Werror)
  endif()
  add_test(NAME bci_core_tests COMMAND bci_core_tests)
  set_tests_properties(bci_core_tests PROPERTIES TIMEOUT 60)
endif()
