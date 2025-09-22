# Multi-Distribution GCC Toolchains for Bazel

This repository provides isolated GCC toolchains built from Linux distribution RPM packages for Bazel builds.

## 🎯 Features

- **Multiple Toolchains**: Support for Fedora, CentOS, and Host system GCC
- **Isolated Builds**: RPM-based toolchains with no host system dependencies
- **Host Integration**: Fast host toolchain using system GCC installation
- **Architecture Support**: x86_64 and aarch64
- **Distribution-Specific Flags**: Configurable compiler flags per toolchain
- **Shared Infrastructure**: Common utilities across all toolchain types
- **Automated Updates**: Unified script to fetch latest package versions

## 🏗️ Repository Structure

```
├── BUILD.bazel              # Root build file with convenience aliases
├── MODULE.bazel              # Multi-toolchain module configuration
├── update_packages.py        # Unified script for package updates
├── common/
│   ├── BUILD.bazel          # Common utilities build file
│   └── toolchain_utils.bzl  # Shared utilities for all toolchains
├── fedora_gcc/
│   ├── BUILD.bazel          # Fedora-specific build file
│   └── extensions.bzl       # Fedora GCC toolchain extension
├── centos_gcc/
│   ├── BUILD.bazel          # CentOS-specific build file
│   └── extensions.bzl       # CentOS GCC toolchain extension
├── host_gcc/
│   ├── BUILD.bazel          # Host system build file
│   └── extensions.bzl       # Host GCC toolchain extension
└── README.md                # This file
```

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

### Using CentOS GCC Toolchain (when ready)

```python
bazel_dep(name = "multi_gcc_toolchain", version = "1.0.0")

# Use the CentOS extension
centos_gcc = use_extension("@multi_gcc_toolchain//centos_gcc:extensions.bzl", "centos_gcc_extension")
use_repo(centos_gcc, "centos_gcc_repo")

# Register the toolchain
register_toolchains("@centos_gcc_repo//:gcc_toolchain_linux_x86_64")
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
# For Fedora
python3 update_packages.py fedora 42 x86_64

# For CentOS
python3 update_packages.py centos 9 x86_64
```

Copy the output into the respective `extensions.bzl` file.

## ✅ Status

- **Fedora GCC Toolchain**: ✅ Fully functional and tested
- **CentOS GCC Toolchain**: 🚧 Framework ready, needs package version updates
- **Host GCC Toolchain**: ✅ Fully functional and tested

## 🎨 Features

- **Convenience Aliases**: Easy access via root BUILD.bazel
- **User Choice**: No auto-registered toolchains - users choose what they need
- **Shared Logic**: Common code between distributions
- **Clean Architecture**: Separate concerns, modular design

## 🔍 Architecture Details

### RPM-Based Toolchains (Fedora/CentOS)

- Isolated GCC compilation environment
- No host system header/library dependencies
- Proper header path isolation with `-nostdinc`/`-nostdinc++`
- Library path isolation with `-B` and `-L` flags
- Download and extract RPM packages for complete self-contained environment
- Distribution-specific compiler flags support

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