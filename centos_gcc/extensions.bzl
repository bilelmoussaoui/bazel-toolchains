"""
CentOS GCC Toolchain for Bazel

This extension provides an isolated GCC toolchain built from CentOS RPM packages.
"""

load("//common:toolchain_utils.bzl", "validate_system_requirements", "get_target_architecture",
     "detect_gcc_version", "calculate_include_dirs", "download_and_extract_packages",
     "generate_build_file", "generate_cc_toolchain_config")

# Configuration
_CENTOS_RELEASE = "9"

# Essential packages for a complete GCC toolchain - organized by architecture
# Note: CentOS uses different package versions and repository structure
_PACKAGES_BY_ARCH = {
    "x86_64": {
        "gcc": {
            "version": "11.5.0-4.el9",
            "sha256": "b6fd630a6312e088452e33d255979f486c2e222488d5b4df5c03e4bbdfb8d4e3",
            "package_dir": "AppStream"
        },
        "gcc-c++": {
            "version": "11.5.0-4.el9",
            "sha256": "bcc44ae358b8c7f1e10e520219ce655bcaf49f940c50b7eb88461c6ac764aab4",
            "package_dir": "AppStream"
        },
        "cpp": {
            "version": "11.5.0-4.el9",
            "sha256": "1f60e22ef7f53e4819c524d44a73d0dbe54d8a3dc2f985c3294bc18c9f9111fd",
            "package_dir": "AppStream"
        },
        "binutils": {
            "version": "2.35.2-60.el9",
            "sha256": "4ee6e13f84fcb44ebeea861296314f8bacff84cfdaa977f1c838b9ffbbf83239",
            "package_dir": "BaseOS"
        },
        "glibc-devel": {
            "version": "2.34-223.el9",
            "sha256": "b381a3b9df065ce9b1e8c4225eae3cd0aa92297550f6c5d830f234f2c1e2d9a6",
            "package_dir": "AppStream"
        },
        "libstdc++-devel": {
            "version": "11.5.0-4.el9",
            "sha256": "d99bce7d0ae01d0434a236a7656c8b2469eab52ea1e83e60061c797158cf9869",
            "package_dir": "AppStream"
        },
        "libstdc++": {
            "version": "11.5.0-4.el9",
            "sha256": "e377ac4138e761d71d978fba9cfed36f4b6414ab32d43ab167a661883d5ea20d",
            "package_dir": "BaseOS"
        },
        "kernel-headers": {
            "version": "5.14.0-617.el9",
            "sha256": "8dc4c726537d55bc412733027802d0a0ef57368da044b574f2c921e3b95f6508",
            "package_dir": "AppStream"
        },
        "glibc-headers": {
            "version": "2.34-223.el9",
            "sha256": "28ae01846d8b945b97b402902e7559b725e2f07f193c868756d0fdfe543c2d31",
            "package_dir": "AppStream"
        },
    },
    "aarch64": {
        "gcc": {
            "version": "11.5.0-4.el9",
            "sha256": "3e69e9371bd387721701475948363b1b9299b11e3ec39c68327e2efdb10582f7",
            "package_dir": "AppStream"
        },
        "gcc-c++": {
            "version": "11.5.0-4.el9",
            "sha256": "fdd3bffceaefcbf4af9b4949a2e61d8b983a1a8b1337e80b28686f05a0baf696",
            "package_dir": "AppStream"
        },
        "cpp": {
            "version": "11.5.0-4.el9",
            "sha256": "19577d2c9b3d51e2b908f1bc63aea2bbeb8d6a2162f7d39553a79e3bce170744",
            "package_dir": "AppStream"
        },
        "binutils": {
            "version": "2.35.2-60.el9",
            "sha256": "7a616e06890a1881b5706123076a41871ad9c4ce48007492eb1d7f7c51c63470",
            "package_dir": "BaseOS"
        },
        "glibc-devel": {
            "version": "2.34-223.el9",
            "sha256": "39fc9464a8df776f244549c8a64cc49e37f75222fe3689b917cd44f6c3968125",
            "package_dir": "AppStream"
        },
        "libstdc++-devel": {
            "version": "11.5.0-4.el9",
            "sha256": "a5fcfa0b1eed31a617f48ceab75003e6e9870558543d1c1585e6eee0753d0484",
            "package_dir": "AppStream"
        },
        "libstdc++": {
            "version": "11.5.0-4.el9",
            "sha256": "d07ad1e2d0246b626c6636e3f55abd258263caba83795dc41ce00f8ce1ebfdfd",
            "package_dir": "BaseOS"
        },
        "kernel-headers": {
            "version": "5.14.0-604.el9",
            "sha256": "95e85dcff6e5cbe76dba33b79be72c51eaf51fa46aac99262bc5d8f25836c7b7",
            "package_dir": "AppStream"
        },
    },
}

def _centos_gcc_toolchain_impl(repository_ctx):
    """Downloads CentOS RPM packages and creates an isolated GCC toolchain.

    This function creates a complete, self-contained GCC toolchain by downloading
    and extracting essential packages from CentOS repositories, then configuring
    them to work independently of the host system.
    """
    # Use shared validation
    validate_system_requirements(repository_ctx)

    # Use shared architecture detection
    rpm_arch = get_target_architecture(repository_ctx)

    # Get packages for the current architecture
    packages = _PACKAGES_BY_ARCH.get(rpm_arch)
    if not packages:
        fail("No packages defined for architecture: {}. Supported architectures: {}".format(
            rpm_arch, list(_PACKAGES_BY_ARCH.keys())
        ))

    # Use shared download and extraction logic
    # CentOS uses different URL structure than Fedora - no subpath needed
    base_url_template = "https://mirror.stream.centos.org/{release}-stream/{package_dir}/{arch}/os/Packages/{pkg_name}-{version}.{arch}.rpm"
    download_and_extract_packages(repository_ctx, packages, base_url_template, _CENTOS_RELEASE, rpm_arch, "CentOS {}".format(_CENTOS_RELEASE))

    # Use shared GCC version detection
    gcc_version, gcc_major = detect_gcc_version(repository_ctx)

    # Use shared include directory calculation
    include_dirs = calculate_include_dirs(rpm_arch, gcc_major)

    # Use shared BUILD file generation
    build_content = generate_build_file(gcc_version, include_dirs, rpm_arch)
    repository_ctx.file("BUILD.bazel", build_content)

    # Define CentOS-specific compiler flags
    centos_flags = {
        "c_flags": [
            # Add CentOS-specific C flags here
            # Example: "-O2", "-g", "-pipe", "-Wall", "-Werror=format-security"
        ],
        "cxx_flags": [
            # Add CentOS-specific C++ flags here
            # Example: "-O2", "-g", "-pipe", "-Wall", "-Werror=format-security"
        ],
        "link_flags": [
            # Add CentOS-specific linker flags here
            # Example: "-Wl,-z,relro", "-Wl,-z,now"
        ]
    }

    # Use shared toolchain config generation
    module_names = {
        "module_name": "multi_gcc_toolchain",
        "extension_name": "centos_gcc_extension",
        "repo_name": "centos_gcc_repo",
        "distro_name": "centos"
    }
    repository_ctx.file("cc_toolchain_config.bzl", generate_cc_toolchain_config(module_names, centos_flags))

# Define the repository rule
centos_gcc_toolchain = repository_rule(
    implementation = _centos_gcc_toolchain_impl,
    doc = "Repository rule for CentOS GCC toolchain",
)

def _centos_gcc_extension_impl(module_ctx):
    """Extension implementation for CentOS GCC toolchain"""
    centos_gcc_toolchain(name = "centos_gcc_repo")

centos_gcc_extension = module_extension(
    implementation = _centos_gcc_extension_impl,
    doc = "Extension for CentOS GCC toolchain",
)
