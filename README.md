# GCC Toolchains for Bazel

GCC toolchains built from Linux RPM packages.

## Features

- **Multiple Toolchains**: Fedora 42 (GCC 15), AutoSD 10 (GCC 14), AutoSD 9 (GCC 11), and Host system GCC
- **Hermetic Builds**: RPM-based toolchains with no host system dependencies
- **Architecture Support**: x86_64 and aarch64
- **Configurable Flags**: Customizable compiler and linker flags with append/replace modes
- **Bzlmod Native**: First-class support for Bazel's modern module system

## Quick Start

```bash
# Try the examples
cd examples/simple_c && bazel run //:hello
cd examples/external_lib && bazel run //:json_demo
```

## Usage

Add to your project's `MODULE.bazel`:

### AutoSD 9 (GCC 11, glibc 2.34)

```python
bazel_dep(name = "multi_gcc_toolchain", version = "1.0.0")

autosd_9_gcc = use_extension("@multi_gcc_toolchain//autosd_9_gcc:extensions.bzl", "autosd_9_gcc_extension")
use_repo(autosd_9_gcc, "autosd_9_gcc_repo")
register_toolchains("@autosd_9_gcc_repo//:gcc_toolchain_linux_x86_64")
```

### AutoSD 10 (GCC 14, glibc 2.39)

```python
autosd_10_gcc = use_extension("@multi_gcc_toolchain//autosd_10_gcc:extensions.bzl", "autosd_10_gcc_extension")
use_repo(autosd_10_gcc, "autosd_10_gcc_repo")
register_toolchains("@autosd_10_gcc_repo//:gcc_toolchain_linux_x86_64")
```

### Fedora 42 (GCC 15, glibc 2.41)

```python
fedora_gcc = use_extension("@multi_gcc_toolchain//fedora_gcc:extensions.bzl", "fedora_gcc_extension")
use_repo(fedora_gcc, "fedora_gcc_repo")
register_toolchains("@fedora_gcc_repo//:gcc_toolchain_linux_x86_64")
```

### Host System

```python
host_gcc = use_extension("@multi_gcc_toolchain//host_gcc:extensions.bzl", "host_gcc_extension")
use_repo(host_gcc, "host_gcc_repo")
register_toolchains("@host_gcc_repo//:gcc_toolchain_linux_x86_64")
```

## Customizing Compiler Flags

Flags are appended to defaults by default:

```python
autosd_9_gcc = use_extension("@multi_gcc_toolchain//autosd_9_gcc:extensions.bzl", "autosd_9_gcc_extension")
autosd_9_gcc.configure(
    c_flags = ["-fPIC", "-Wno-error=maybe-uninitialized"],
    cxx_flags = ["-fPIC", "-Wno-error=maybe-uninitialized"],
)
use_repo(autosd_9_gcc, "autosd_9_gcc_repo")
```

To replace defaults entirely:

```python
autosd_9_gcc.configure(
    c_flags = ["-O3", "-march=native"],
    replace = True,
)
```

### Default Flags

**AutoSD 9/10:**
- C/C++: `-O2 -g -pipe -Wall -Werror=format-security`
- Linker: `-Wl,-z,relro -Wl,-z,now`

**Fedora 42:**
- C: `-O2 -g -pipe -fstack-protector-strong -Wpedantic`
- C++: `-O2 -g -pipe -fstack-protector-strong`
- Linker: `-Wl,-z,relro -Wl,-z,now`

**Host:**
- No default flags (minimal configuration)

## Architecture

### RPM-Based Toolchains

- Self-contained environments with no host dependencies
- Header isolation via `-nostdinc`/`-nostdinc++`
- Sysroot-based linking with `--sysroot`
- Dynamic package discovery and download (always uses latest versions)
- Automatic RPM download and extraction

### Host Toolchain

- Uses system-installed GCC
- Automatic detection of system headers and libraries
- Fast builds with no download overhead
- Ideal for local development

## Repository Structure

```
├── common/              # Shared toolchain utilities and templates
├── fedora_gcc/          # Fedora 42 GCC 15 toolchain
├── autosd_10_gcc/       # AutoSD 10 GCC 14 toolchain
├── autosd_9_gcc/        # AutoSD 9 GCC 11 toolchain
├── host_gcc/            # Host system GCC toolchain
├── constraints/         # Platform constraint definitions
├── containers/          # Container images for testing
└── examples/            # Usage examples
```

## License

See LICENSE file for details.
