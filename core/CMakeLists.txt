cmake_minimum_required(VERSION 3.21)
project(bci_engine_core VERSION 0.1.0 LANGUAGES CXX)

# Tests are built explicitly by scripts/build_core.sh (standalone builds);
# as a Flutter subproject the default stays OFF to keep app builds lean.
option(BCI_BUILD_TESTS "Build BCI core tests (Catch2)" OFF)
option(BCI_FETCH_DEPS "Fetch third-party deps from the network" ON)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_CXX_EXTENSIONS OFF)
set(CMAKE_POSITION_INDEPENDENT_CODE ON)

# ---------------------------------------------------------------- third-party
# readerwriterqueue (header-only, lock-free SPSC queue).
# Downloaded to the build dir; if the download fails the build silently falls
# back to the internal SPSC ring implementation (see src/spsc_queue.hpp).
set(BCI_HAVE_RWQ 0)
if(BCI_FETCH_DEPS)
  set(BCI_THIRDPARTY_DIR "${CMAKE_BINARY_DIR}/thirdparty")
  set(RWQ_DIR "${BCI_THIRDPARTY_DIR}/readerwriterqueue-1.0.6")
  if(NOT EXISTS "${RWQ_DIR}/readerwriterqueue.h")
    set(RWQ_URL "https://github.com/cameron314/readerwriterqueue/archive/refs/tags/v1.0.6.tar.gz")
    set(RWQ_TARBALL "${BCI_THIRDPARTY_DIR}/readerwriterqueue-1.0.6.tar.gz")
    file(DOWNLOAD "${RWQ_URL}" "${RWQ_TARBALL}" STATUS RWQ_DL)
    list(GET RWQ_DL 0 RWQ_DL_CODE)
    if(RWQ_DL_CODE EQUAL 0)
      file(ARCHIVE_EXTRACT INPUT "${RWQ_TARBALL}" DESTINATION "${BCI_THIRDPARTY_DIR}")
    else()
      message(WARNING "readerwriterqueue download failed (code ${RWQ_DL_CODE}); using internal SPSC queue")
    endif()
  endif()
  if(EXISTS "${RWQ_DIR}/readerwriterqueue.h")
    set(BCI_HAVE_RWQ 1)
  endif()
endif()

# ---------------------------------------------------------------- core library
set(BCI_CORE_SOURCES
  src/version.cpp
  src/engine.cpp
  src/modules.cpp
  src/fft.cpp
  src/c_api.cpp
)

add_library(bci_engine_core SHARED ${BCI_CORE_SOURCES})

target_include_directories(bci_engine_core
  PUBLIC
    ${CMAKE_CURRENT_SOURCE_DIR}/include
  PRIVATE
    ${CMAKE_CURRENT_SOURCE_DIR}/src
)

if(BCI_HAVE_RWQ)
  target_include_directories(bci_engine_core PRIVATE "${RWQ_DIR}")
  target_compile_definitions(bci_engine_core PRIVATE BCI_HAVE_RWQ=1)
endif()

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
set(BCI_TEST_READY 0)
if(BCI_BUILD_TESTS)
  set(CATCH2_DIR "${CMAKE_BINARY_DIR}/thirdparty/catch2-v2.13.10")
  set(CATCH2_HEADER "${CATCH2_DIR}/catch.hpp")
  if(NOT EXISTS "${CATCH2_HEADER}")
    file(DOWNLOAD
      "https://github.com/catchorg/Catch2/releases/download/v2.13.10/catch.hpp"
      "${CATCH2_HEADER}" STATUS CATCH_DL)
    list(GET CATCH_DL 0 CATCH_DL_CODE)
    if(NOT CATCH_DL_CODE EQUAL 0)
      message(WARNING "Catch2 download failed (code ${CATCH_DL_CODE}); tests are skipped")
    endif()
  endif()
  if(EXISTS "${CATCH2_HEADER}")
    set(BCI_TEST_READY 1)
  endif()
endif()

if(BCI_TEST_READY)
  enable_testing()
  add_executable(bci_core_tests tests/test_core.cpp)
  target_include_directories(bci_core_tests PRIVATE "${CATCH2_DIR}")
  target_link_libraries(bci_core_tests PRIVATE bci_engine_core)
  if(MSVC)
    target_compile_options(bci_core_tests PRIVATE /W4)
  else()
    target_compile_options(bci_core_tests PRIVATE -Wall -Wextra -Werror)
  endif()
  add_test(NAME bci_core_tests COMMAND bci_core_tests)
endif()
