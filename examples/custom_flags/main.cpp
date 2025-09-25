#include <iostream>
#include <vector>
#include <algorithm>

int main() {
    std::cout << "Custom Flags Demo - C++ Version\n";
    std::cout << "==================================\n";

    std::cout << "Compiled with GCC version: "
              << __GNUC__ << "." << __GNUC_MINOR__ << "." << __GNUC_PATCHLEVEL__ << "\n";

    std::cout << "C++ Standard: " << __cplusplus << "\n";

#ifdef NDEBUG
    std::cout << "Build type: Release (NDEBUG defined)\n";
#else
    std::cout << "Build type: Debug (NDEBUG not defined)\n";
#endif

#ifdef CUSTOM_DEFINE
    std::cout << "Custom define: CUSTOM_DEFINE = " << CUSTOM_DEFINE << "\n";
#else
    std::cout << "Custom define: CUSTOM_DEFINE not defined\n";
#endif

#ifdef __OPTIMIZE__
    std::cout << "Optimization: Enabled (__OPTIMIZE__ defined)\n";
#else
    std::cout << "Optimization: Disabled\n";
#endif

    // Test C++17 features if enabled
    std::vector<int> numbers = {5, 2, 8, 1, 9};
    std::sort(numbers.begin(), numbers.end());

    std::cout << "\nSorted numbers: ";
    for (const auto& num : numbers) {
        std::cout << num << " ";
    }
    std::cout << "\n";

    std::cout << "\nThis demonstrates custom C++ compiler flags!\n";
    std::cout << "Check the build command to see the custom flags being used.\n";

    return 0;
}