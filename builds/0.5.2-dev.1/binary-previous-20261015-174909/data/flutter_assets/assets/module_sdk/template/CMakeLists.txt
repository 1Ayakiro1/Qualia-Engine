cmake_minimum_required(VERSION 3.21)
project(qualia_local_module LANGUAGES CXX)
set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
add_executable(module main.cpp)
target_include_directories(module PRIVATE include)
set_target_properties(module PROPERTIES
  BUILD_RPATH "$ORIGIN/../lib"
  INSTALL_RPATH "$ORIGIN/../lib"
)
target_compile_options(module PRIVATE -Wall -Wextra -Wpedantic)
