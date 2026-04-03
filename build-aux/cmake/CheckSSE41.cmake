include(CheckCXXSourceCompiles)
include(CheckCXXCompilerFlag)

check_cxx_compiler_flag("-msse4.1" HAVE_FLAG_SSE41)

set(SSE41_TEST_FLAGS_STR "")
set(SSE41_TEST_FLAGS_LIST "")

if(HAVE_FLAG_SSE41)
    string(APPEND SSE41_TEST_FLAGS_STR " -msse4.1")
    list(APPEND SSE41_TEST_FLAGS_LIST "-msse4.1")
endif()

set(CMAKE_REQUIRED_FLAGS "${SSE41_TEST_FLAGS_STR}")

# Use 'a' in the return to avoid unused variable warnings
check_cxx_source_compiles("
    #include <smmintrin.h>
    #include <stdint.h>
    int main() {
        __m128i a = _mm_set1_epi32(0);
        return _mm_extract_epi32(a, 0);
    }"
    HAS_SSE41
)

unset(CMAKE_REQUIRED_FLAGS)

if(HAS_SSE41)
    # We export a LIST (semicolon separated) which is safer for CMake
    set(SSE41_FLAGS "${SSE41_TEST_FLAGS_LIST}" CACHE STRING "Flags for SSE4.1" FORCE)
else()
    set(SSE41_FLAGS "" CACHE STRING "Flags for SSE4.1" FORCE)
endif()
