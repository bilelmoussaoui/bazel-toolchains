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
            "version": "11.5.0-11.el9",
            "sha256": "",  # To be filled by update script
            "subpath": ""
        },
        "gcc-c++": {
            "version": "11.5.0-11.el9",
            "sha256": "",  # To be filled by update script
            "subpath": ""
        },
        "cpp": {
            "version": "11.5.0-11.el9",
            "sha256": "",  # To be filled by update script
            "subpath": ""
        },
        "binutils": {
            "version": "2.44-2.el9",
            "sha256": "",  # To be filled by update script
            "subpath": ""
        },
        "glibc-devel": {
            "version": "2.34-232.el9",
            "sha256": "42e6ad29fc25a5a79635f17be4189950adcddf1e03f3060ab950ae362650c254",
            "subpath": ""
        },
        "libstdc++-devel": {
            "version": "11.5.0-11.el9",
            "sha256": "",  # To be filled by update script
            "subpath": ""
        },
        "libstdc++": {
            "version": "11.5.0-11.el9",
            "sha256": "",  # To be filled by update script
            "subpath": ""
        },
    },
    "aarch64": {
        "gcc": {
            "version": "11.4.1-3.el9",
            "sha256": "",  # To be filled by update script
            "subpath": ""
        },
        "gcc-c++": {
            "version": "11.4.1-3.el9",
            "sha256": "",  # To be filled by update script
            "subpath": ""
        },
        "cpp": {
            "version": "11.4.1-3.el9",
            "sha256": "",  # To be filled by update script
            "subpath": ""
        },
        "binutils": {
            "version": "2.35.2-48.el9",
            "sha256": "",  # To be filled by update script
            "subpath": ""
        },
        "glibc-devel": {
            "version": "2.34-83.el9.7",
            "sha256": "",  # To be filled by update script
            "subpath": ""
        },
        "libstdc++-devel": {
            "version": "11.4.1-3.el9",
            "sha256": "",  # To be filled by update script
            "subpath": ""
        },
        "libstdc++": {
            "version": "11.4.1-3.el9",
            "sha256": "",  # To be filled by update script
            "subpath": ""
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
    base_url_template = "https://mirror.stream.centos.org/{release}-stream/AppStream/{arch}/os/Packages/{pkg_name}-{version}.{arch}.rpm"
    download_and_extract_packages(repository_ctx, packages, base_url_template, _CENTOS_RELEASE, rpm_arch, "CentOS {}".format(_CENTOS_RELEASE))

    # Use shared GCC version detection
    gcc_version, gcc_major = detect_gcc_version(repository_ctx)

    # Use shared include directory calculation
    include_dirs = calculate_include_dirs(rpm_arch, gcc_major)

    # Use shared BUILD file generation
    build_content = generate_build_file(gcc_version, include_dirs, rpm_arch)
    repository_ctx.file("BUILD.bazel", build_content)

    # Use shared toolchain config generation
    module_names = {
        "module_name": "multi_gcc_toolchain",
        "extension_name": "centos_gcc_extension",
        "repo_name": "centos_gcc_repo",
        "distro_name": "centos"
    }
    repository_ctx.file("cc_toolchain_config.bzl", generate_cc_toolchain_config(module_names))

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