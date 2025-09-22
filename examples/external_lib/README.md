# External Library Example

This directory contains a C++ program that demonstrates using a proper external library dependency managed by Bazel.

## Features

- **External Bazel Dependency**: Uses `nlohmann/json` library via `bazel_dep`
- **Header-Only Library**: Demonstrates integration with header-only C++ libraries
- **Modern C++**: Uses C++11/14/17 features with JSON manipulation
- **Proper Dependency Management**: Library is fetched and built by Bazel

## Building

```bash
# Build the JSON demo
bazel build //:json_demo

# Build the statically linked version
bazel build //:json_demo_static

# Run the program
bazel run //:json_demo
```

## Dependencies

The example uses:

- **nlohmann/json**: A popular modern C++ JSON library
- **Bazel Central Registry**: Fetches the library automatically via `bazel_dep`
- **Header-Only**: No separate compilation needed, just include and use

## Switching Toolchains

Edit `MODULE.bazel` to switch between toolchains:

- **Host toolchain**: Fast, uses system GCC and standard libraries (default)
- **Fedora toolchain**: Isolated, uses Fedora RPM toolchain
- **CentOS toolchain**: Isolated, uses CentOS RPM toolchain

All toolchains will compile the external library using their respective compilers and standard libraries.

## Output

The program will:

1. Create JSON objects using the nlohmann/json library
2. Parse JSON strings with error handling
3. Demonstrate modern C++ features (range-based loops, structured bindings)
4. Show library version information
5. Display GCC compiler version used

This demonstrates that the toolchains properly handle:

- External library dependencies via Bazel
- C++ compilation with modern standards
- Header-only library integration
- Cross-toolchain library compatibility