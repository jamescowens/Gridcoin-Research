include(CheckCXXSourceCompiles)
include(CheckCXXCompilerFlag)

# 1. Check for the flags
# We need both -msha (for the sha instructions) and usually -msse4 (for the setup)
check_cxx_compiler_flag("-msha" HAVE_FLAG_MSHA)
check_cxx_compiler_flag("-msse4" HAVE_FLAG_SSE4)

set(SHANI_TEST_FLAGS_STR "")
set(SHANI_TEST_FLAGS_LIST "")

if(HAVE_FLAG_MSHA)
    string(APPEND SHANI_TEST_FLAGS_STR " -msha")
    list(APPEND SHANI_TEST_FLAGS_LIST "-msha")
endif()
if(HAVE_FLAG_SSE4)
    string(APPEND SHANI_TEST_FLAGS_STR " -msse4")
    list(APPEND SHANI_TEST_FLAGS_LIST "-msse4")
endif()

# 2. Setup environment using the STRING version
set(CMAKE_REQUIRED_FLAGS "${SHANI_TEST_FLAGS_STR}")

# 3. Run the test
# We use (i, j, k) to ensure 'j' is used and doesn't trigger "unused variable" errors
check_cxx_source_compiles("
    #include <stdint.h>
    #include <immintrin.h>

    int main() {
        __m128i i = _mm_set1_epi32(0);
        __m128i j = _mm_set1_epi32(1);
        __m128i k = _mm_set1_epi32(2);
        /* _mm_sha256rnds2_epu32(state_a, state_b, key) */
        return _mm_extract_epi32(_mm_sha256rnds2_epu32(i, j, k), 0);
    }"
    HAS_X86_SHANI
)

# 4. Cleanup and Export
unset(CMAKE_REQUIRED_FLAGS)

if(HAS_X86_SHANI)
    # Export the LIST version (semicolon-separated) for safe CMake usage
    set(X86_SHANI_FLAGS "${SHANI_TEST_FLAGS_LIST}" CACHE STRING "Flags for SHA-NI" FORCE)
else()
    set(X86_SHANI_FLAGS "" CACHE STRING "Flags for SHA-NI" FORCE)
endif()
