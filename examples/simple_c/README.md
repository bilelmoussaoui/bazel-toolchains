# Simple C Example

This directory contains a simple C program that demonstrates using the GCC toolchains.

## Building

```bash
# Build the hello program
bazel build //:hello

# Build the statically linked version
bazel build //:hello_static

# Run the program
bazel run //:hello

# Run with arguments
bazel run //:hello -- arg1 arg2 arg3
```

## Switching Toolchains

Edit `MODULE.bazel` to switch between toolchains:

- **Host toolchain**: Fast, uses system GCC (default)
- **Fedora toolchain**: Isolated, downloads Fedora RPMs
- **CentOS toolchain**: Isolated, downloads CentOS RPMs

Simply comment/uncomment the appropriate sections in `MODULE.bazel`.

## Output

The program will show:

- A hello message
- Any command-line arguments provided
- The GCC version used for compilation