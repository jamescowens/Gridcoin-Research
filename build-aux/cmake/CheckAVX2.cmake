include(CheckCXXSourceCompiles)
include(CheckCXXCompilerFlag)

check_cxx_compiler_flag("-mavx" HAVE_FLAG_AVX)
check_cxx_compiler_flag("-mavx2" HAVE_FLAG_AVX2)

set(AVX2_TEST_FLAGS_STR "")
set(AVX2_TEST_FLAGS_LIST "")

if(HAVE_FLAG_AVX)
    string(APPEND AVX2_TEST_FLAGS_STR " -mavx")
    list(APPEND AVX2_TEST_FLAGS_LIST "-mavx")
endif()
if(HAVE_FLAG_AVX2)
    string(APPEND AVX2_TEST_FLAGS_STR " -mavx2")
    list(APPEND AVX2_TEST_FLAGS_LIST "-mavx2")
endif()

set(CMAKE_REQUIRED_FLAGS "${AVX2_TEST_FLAGS_STR}")

# Use 'a' in the return to prevent unused variable warnings
check_cxx_source_compiles("
    #include <immintrin.h>
    #include <stdint.h>
    int main() {
        __m256i a = _mm256_set1_epi32(0);
        return _mm256_extract_epi32(a, 0);
    }"
    HAS_AVX2
)

unset(CMAKE_REQUIRED_FLAGS)

if(HAS_AVX2)
    set(AVX2_FLAGS "${AVX2_TEST_FLAGS_LIST}" CACHE STRING "Flags for AVX2" FORCE)
else()
    set(AVX2_FLAGS "" CACHE STRING "Flags for AVX2" FORCE)
endif()
