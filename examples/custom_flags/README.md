# Custom Flags Example

This example demonstrates how to configure custom compiler and linker flags when using the Fedora GCC toolchain.

## Features Demonstrated

1. **Custom Compiler Flags**: Shows how to override default optimization and add custom defines
2. **Multiple Configure Tags**: Demonstrates merging flags from multiple configure tags within the same module
3. **C and C++ Specific Flags**: Shows different flag configuration for C and C++ compilation
4. **Custom Linker Flags**: Demonstrates custom linking options like LTO and stripping

## Configuration

The `MODULE.bazel` file shows how to configure custom flags:

```python
# Configure Fedora toolchain with custom flags
fedora_gcc = use_extension("@multi_gcc_toolchain//fedora_gcc:extensions.bzl", "fedora_gcc_extension")

# Custom optimization and debug flags
fedora_gcc.configure(
    c_flags = ["-O3", "-DNDEBUG", "-march=native"],
    cxx_flags = ["-O3", "-DNDEBUG", "-march=native", "-std=c++17"],
    link_flags = ["-flto", "-s"],
)

# Additional flags (merged with the above)
fedora_gcc.configure(
    c_flags = ["-DCUSTOM_DEFINE=1"],
    cxx_flags = ["-DCUSTOM_DEFINE=1"],
)
```

## Custom Flags Used

### C Flags
- `-O3`: Maximum optimization
- `-DNDEBUG`: Release build
- `-march=native`: Optimize for current CPU
- `-DCUSTOM_DEFINE=1`: Custom preprocessor define

### C++ Flags
- Same as C flags, plus:
- `-std=c++17`: Use C++17 standard

### Link Flags
- `-flto`: Link-time optimization
- `-s`: Strip debug symbols

## Building and Running

```bash
cd examples/custom_flags

# Build both demos
bazel build //...

# Run the C demo
./bazel-bin/custom_flags_demo

# Run the C++ demo
./bazel-bin/custom_flags_demo_cpp

# See the actual compilation commands with custom flags
bazel build //... --verbose_failures -s
```

## Expected Output

Both programs will show:
- GCC version information
- Whether NDEBUG is defined (release build)
- Whether CUSTOM_DEFINE is set
- Whether optimization is enabled

The C++ version will additionally show the C++ standard version and demonstrate C++17 features.