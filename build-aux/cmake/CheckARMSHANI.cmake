include(CheckCXXSourceCompiles)
include(CheckCXXCompilerFlag)

check_cxx_compiler_flag("-march=armv8-a+crc+crypto" HAVE_FLAG_ARM_CRYPTO)

set(ARM_SHANI_TEST_FLAGS_STR "")
set(ARM_SHANI_TEST_FLAGS_LIST "")

if(HAVE_FLAG_ARM_CRYPTO)
    string(APPEND ARM_SHANI_TEST_FLAGS_STR " -march=armv8-a+crc+crypto")
    list(APPEND ARM_SHANI_TEST_FLAGS_LIST "-march=armv8-a+crc+crypto")
endif()

set(CMAKE_REQUIRED_FLAGS "${ARM_SHANI_TEST_FLAGS_STR}")

check_cxx_source_compiles("
    #include <arm_acle.h>
    #include <arm_neon.h>
    int main() {
        uint32x4_t a = vdupq_n_u32(0);
        uint32x4_t b = vdupq_n_u32(0);
        uint32x4_t c = vdupq_n_u32(0);
        uint32x4_t res = vsha256h2q_u32(a, b, c);
        return vgetq_lane_u32(res, 0);
    }"
    HAS_ARM_SHANI
)

unset(CMAKE_REQUIRED_FLAGS)

if(HAS_ARM_SHANI)
    set(ARM_SHANI_FLAGS "${ARM_SHANI_TEST_FLAGS_LIST}" CACHE STRING "Flags for ARM SHA-NI" FORCE)
else()
    set(ARM_SHANI_FLAGS "" CACHE STRING "Flags for ARM SHA-NI" FORCE)
endif()
