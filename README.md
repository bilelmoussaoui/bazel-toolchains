# Multi-Distribution GCC Toolchains for Bazel

This repository provides isolated GCC toolchains built from Linux distribution RPM packages for Bazel builds.

## 🎯 Features

- **Multiple Distributions**: Support for Fedora and CentOS (framework ready)
- **Isolated Builds**: No host system dependencies
- **Architecture Support**: x86_64 and aarch64
- **Automated Updates**: Unified script to fetch latest package versions

## 🏗️ Repository Structure

```
├── BUILD.bazel              # Root build file with convenience aliases
├── MODULE.bazel              # Multi-toolchain module configuration
├── update_packages.py        # Unified script for both distributions
├── fedora_gcc/
│   ├── BUILD.bazel          # Fedora-specific build file
│   └── extensions.bzl       # Fedora GCC toolchain extension
├── centos_gcc/
│   ├── BUILD.bazel          # CentOS-specific build file
│   └── extensions.bzl       # CentOS GCC toolchain extension (needs package updates)
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

## 🎨 Features

- **Convenience Aliases**: Easy access via root BUILD.bazel
- **User Choice**: No auto-registered toolchains - users choose what they need
- **Shared Logic**: Common code between distributions
- **Clean Architecture**: Separate concerns, modular design

## 🔍 Architecture Details

Each toolchain provides:
- Isolated GCC compilation environment
- No host system header/library dependencies
- Proper header path isolation with `-nostdinc`/`-nostdinc++`
- Library path isolation with `-B` and `-L` flags
- Support for both C and C++ compilation
- Both static and dynamic linking support

The toolchains download and extract RPM packages to create a complete, self-contained GCC environment that works consistently across different host systems.