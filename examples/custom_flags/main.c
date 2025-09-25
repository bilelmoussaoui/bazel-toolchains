#include <stdio.h>

int main() {
    printf("Custom Flags Demo - C Version\n");
    printf("================================\n");

    printf("Compiled with GCC version: %d.%d.%d\n",
           __GNUC__, __GNUC_MINOR__, __GNUC_PATCHLEVEL__);

#ifdef NDEBUG
    printf("Build type: Release (NDEBUG defined)\n");
#else
    printf("Build type: Debug (NDEBUG not defined)\n");
#endif

#ifdef CUSTOM_DEFINE
    printf("Custom define: CUSTOM_DEFINE = %d\n", CUSTOM_DEFINE);
#else
    printf("Custom define: CUSTOM_DEFINE not defined\n");
#endif

#ifdef __OPTIMIZE__
    printf("Optimization: Enabled (__OPTIMIZE__ defined)\n");
#else
    printf("Optimization: Disabled\n");
#endif

    printf("\nThis demonstrates custom compiler flags in action!\n");
    printf("Check the build command to see the custom flags being used.\n");

    return 0;
}