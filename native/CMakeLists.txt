cmake_minimum_required(VERSION 3.20)
project(stellar_coop LANGUAGES CXX)
set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_MSVC_RUNTIME_LIBRARY "MultiThreaded") # No runtime DLL to ship.
add_library(StellarCoop SHARED src/steam_probe.cpp)
set_target_properties(StellarCoop PROPERTIES PREFIX "")
