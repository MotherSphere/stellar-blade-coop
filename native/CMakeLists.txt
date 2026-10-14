cmake_minimum_required(VERSION 3.20)
project(stellar_coop LANGUAGES CXX)
set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_MSVC_RUNTIME_LIBRARY "MultiThreaded") # No runtime DLL to ship.
add_library(StellarCoop SHARED src/steam_link.cpp src/pose_tick.cpp)
set_target_properties(StellarCoop PROPERTIES PREFIX "")
set(STELLARCOOP_VERSION "dev" CACHE STRING "Version baked into the DLL (tools/install.py passes git describe)")
target_compile_definitions(StellarCoop PRIVATE STELLARCOOP_VERSION="${STELLARCOOP_VERSION}")
