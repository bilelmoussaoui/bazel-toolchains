# Multi-Distribution GCC Toolchains for Bazel

This repository provides isolated GCC toolchains built from Linux distribution RPM packages for Bazel builds.

## 🎯 Features

- **Multiple Toolchains**: Support for Fedora 42, AutoSD 10, AutoSD 9, and Host system GCC
- **Isolated Builds**: RPM-based toolchains with no host system dependencies
- **Host Integration**: Fast host toolchain using system GCC installation
- **Architecture Support**: x86_64 and aarch64
- **Multiple GCC Versions**: GCC 15 (Fedora 42), GCC 14 (AutoSD 10), GCC 11 (AutoSD 9)

## 🏗️ Repository Structure

```
├── BUILD.bazel              # Root build file with convenience aliases
├── MODULE.bazel              # Multi-toolchain module configuration
├── update_packages.py        # Unified script for package updates
├── common/
│   ├── BUILD.bazel          # Common utilities build file
│   └── toolchain_utils.bzl  # Shared utilities for all toolchains
├── fedora_gcc/
│   ├── BUILD.bazel          # Fedora 42 GCC 15 build file
│   └── extensions.bzl       # Fedora GCC toolchain extension
├── autosd_10_gcc/
│   ├── BUILD.bazel          # AutoSD 10 GCC 14 build file
│   └── extensions.bzl       # AutoSD 10 GCC toolchain extension
├── autosd_9_gcc/
│   ├── BUILD.bazel          # AutoSD 9 GCC 11 build file
│   └── extensions.bzl       # AutoSD 9 GCC toolchain extension
├── host_gcc/
│   ├── BUILD.bazel          # Host system build file
│   └── extensions.bzl       # Host GCC toolchain extension
├── examples/
│   ├── simple_c/            # Simple C example project
│   │   ├── BUILD.bazel      # Basic example build file
│   │   ├── MODULE.bazel     # Example module configuration
│   │   ├── hello.c          # Basic C source code
│   │   └── README.md        # Example documentation
│   └── external_lib/        # External library example project
│       ├── BUILD.bazel      # Example with Bazel external dependencies
│       ├── MODULE.bazel     # Example module configuration
│       ├── main.cpp         # C++ with nlohmann/json library
│       └── README.md        # Example documentation
└── README.md                # This file
```

## 🚀 Quick Start

Try the example projects:

```bash
# Basic C program example
cd examples/simple_c
bazel run //:hello

# External library example (uses nlohmann/json)
cd examples/external_lib
bazel run //:json_demo
```

Both examples use the host GCC toolchain by default for fast builds.

## 🚀 Usage

### Using Fedora GCC Toolchain

In your project's `MODULE.bazel`:

```python
bazel_dep(name = "multi_gcc_toolchain", version = "1.0.0")

# Use the Fedora extension
fedora_gcc = use_extension("@multi_gcc_toolchain//fedora_gcc:extensions.bzl", "fedora_gcc_extension")
use_repo(fedora_gcc, "fedora_gcc_repo")

# Register the toolchain
register_toolchains("@fedora_gcc_repo//:gcc_toolchain_linux_x86_64")
```

### Using AutoSD 10 GCC Toolchain (GCC 14)

```python
bazel_dep(name = "multi_gcc_toolchain", version = "1.0.0")

# Use the AutoSD 10 extension
autosd_10_gcc = use_extension("@multi_gcc_toolchain//autosd_10_gcc:extensions.bzl", "autosd_10_gcc_extension")
use_repo(autosd_10_gcc, "autosd_10_gcc_repo")

# Register the toolchain
register_toolchains("@autosd_10_gcc_repo//:gcc_toolchain_linux_x86_64")
```

### Using AutoSD 9 GCC Toolchain (GCC 11)

```python
bazel_dep(name = "multi_gcc_toolchain", version = "1.0.0")

# Use the AutoSD 9 extension
autosd_9_gcc = use_extension("@multi_gcc_toolchain//autosd_9_gcc:extensions.bzl", "autosd_9_gcc_extension")
use_repo(autosd_9_gcc, "autosd_9_gcc_repo")

# Register the toolchain
register_toolchains("@autosd_9_gcc_repo//:gcc_toolchain_linux_x86_64")
```

### Using Host GCC Toolchain

```python
bazel_dep(name = "multi_gcc_toolchain", version = "1.0.0")

# Use the Host extension
host_gcc = use_extension("@multi_gcc_toolchain//host_gcc:extensions.bzl", "host_gcc_extension")
use_repo(host_gcc, "host_gcc_repo")

# Register the toolchain
register_toolchains("@host_gcc_repo//:gcc_toolchain_linux_x86_64")
```

## 🔧 Updating Package Versions

Use the unified update script to fetch the latest package versions and SHA256 hashes:

```bash
# For Fedora 42
python3 update_packages.py fedora 42 x86_64

# For AutoSD 10 (CentOS Stream 10)
python3 update_packages.py centos 10 x86_64

# For AutoSD 9 (CentOS Stream 9)
python3 update_packages.py centos 9 x86_64
```

Copy the output into the respective `extensions.bzl` file.

## ✅ Status

- **Fedora 42 GCC Toolchain (GCC 15)**: ✅ Fully functional and tested
- **AutoSD 10 GCC Toolchain (GCC 14)**: ✅ Fully functional and tested on x86_64
- **AutoSD 9 GCC Toolchain (GCC 11)**: ✅ Fully functional and tested on x86_64
- **Host GCC Toolchain**: ✅ Fully functional and tested

## 🎨 Features

- **Convenience Aliases**: Easy access via root BUILD.bazel
- **User Choice**: No auto-registered toolchains - users choose what they need
- **Shared Logic**: Common code between distributions
- **Clean Architecture**: Separate concerns, modular design

## 🔍 Architecture Details

### RPM-Based Toolchains (Fedora/AutoSD)

- Isolated GCC compilation environment
- No host system header/library dependencies
- Proper header path isolation with `-nostdinc`/`-nostdinc++`
- Library path isolation with `-B` and `-L` flags
- Sysroot-based linking for static and dynamic library support
- Download and extract RPM packages for complete self-contained environment
- Distribution-specific compiler flags support
- **Fedora 42**: GCC 15.0.1, glibc 2.41
- **AutoSD 10**: GCC 14.3.1, glibc 2.39 (CentOS Stream 10)
- **AutoSD 9**: GCC 11.5.0, glibc 2.34 (CentOS Stream 9)

### Host System Toolchain

- Uses existing system GCC installation
- Automatic detection of system headers and libraries
- Fast builds (no downloads or extractions needed)
- Integrates with host package manager maintained tools
- Distribution-specific compiler flags support

All toolchains provide:

- Support for both C and C++ compilation
- Both static and dynamic linking support
- Architecture detection (x86_64/aarch64)
- Consistent configuration interface
