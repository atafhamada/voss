cmake_minimum_required(VERSION 3.22)

project(voss_core
    VERSION 0.1.0
    DESCRIPTION "VOSS: GPU-accelerated prime gap library"
    LANGUAGES CXX CUDA
)

# === Standards ===
set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_CUDA_STANDARD 17)
set(CMAKE_CUDA_STANDARD_REQUIRED ON)

# === Default build type ===
if(NOT CMAKE_BUILD_TYPE)
    set(CMAKE_BUILD_TYPE Release)
endif()

# === CUDA architectures ===
# Override Colab's default (52) — Tier 1: T4=sm_75, A100=sm_80
# Can be overridden: cmake -DVOSS_CUDA_ARCHS="75;80;90" ...
if(NOT VOSS_CUDA_ARCHS)
    set(VOSS_CUDA_ARCHS "75;80")
endif()
set(CMAKE_CUDA_ARCHITECTURES "${VOSS_CUDA_ARCHS}"
    CACHE STRING "CUDA architectures to build for" FORCE)

# ============================================================
# Library: libvoss_core.a
# ============================================================
add_library(voss_core STATIC
    src/core/error.cpp
    src/core/cuda_context.cpp
    src/core/memory.cpp
    src/primes/prime_count.cpp
    src/primes/sieve.cu
    src/primes/extract.cu
)

target_include_directories(voss_core
    PUBLIC  ${CMAKE_CURRENT_SOURCE_DIR}/include
    PRIVATE ${CMAKE_CURRENT_SOURCE_DIR}/src
)

target_compile_options(voss_core PRIVATE
    $<$<COMPILE_LANGUAGE:CUDA>:--use_fast_math>
)

target_compile_options(voss_core PRIVATE
    $<$<COMPILE_LANGUAGE:CXX>:-Wall -Wextra>
)

# ============================================================
# Test binary: test_prime_count
# ============================================================
add_executable(test_prime_count tests/test_prime_count.cpp)
target_link_libraries(test_prime_count PRIVATE voss_core)

# ============================================================
# Summary
# ============================================================
message(STATUS "")
message(STATUS "=== VOSS build configuration ===")
message(STATUS "  Build type:         ${CMAKE_BUILD_TYPE}")
message(STATUS "  CXX standard:       ${CMAKE_CXX_STANDARD}")
message(STATUS "  CUDA standard:      ${CMAKE_CUDA_STANDARD}")
message(STATUS "  CUDA architectures: ${CMAKE_CUDA_ARCHITECTURES}")
message(STATUS "  CUDA compiler:      ${CMAKE_CUDA_COMPILER}")
message(STATUS "  CUDA version:       ${CMAKE_CUDA_COMPILER_VERSION}")
message(STATUS "")
