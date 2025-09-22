"""
Fedora GCC Toolchain for Bazel

This extension provides an isolated GCC toolchain built from Fedora RPM packages.
"""

load("//common:toolchain_utils.bzl", "validate_system_requirements", "get_target_architecture",
     "detect_gcc_version", "calculate_include_dirs", "download_and_extract_packages",
     "generate_build_file", "generate_cc_toolchain_config")

# Configuration
_FEDORA_RELEASE = "42"

# Essential packages for a complete GCC toolchain - organized by architecture
_PACKAGES_BY_ARCH = {
    "x86_64": {
        "gcc": {
            "version": "15.0.1-0.11.fc42",
            "sha256": "ee378a7143cafe3beb7035ac429435f7299fb81575a1572aeefb18dcead0441f",
            "subpath": "g"
        },
        "gcc-c++": {
            "version": "15.0.1-0.11.fc42",
            "sha256": "e88aaf855b960a5d910eaf1730164d1a12f82ddc3704a1fcce4d5c2ad4f6fa69",
            "subpath": "g"
        },
        "cpp": {
            "version": "15.0.1-0.11.fc42",
            "sha256": "6007918d3963b22c35d9199437c9067b9250d063afadc7ea91fc0b2fb6aabc5e",
            "subpath": "c"
        },
        "binutils": {
            "version": "2.44-3.fc42",
            "sha256": "9657d854cbe19334c9bd7b12ceca74f0690fa60f7a5135330dbdfcab8bf6631a",
            "subpath": "b"
        },
        "glibc-devel": {
            "version": "2.41-1.fc42",
            "sha256": "b386558a3fbb08e899c0cd93e9a23e5a5e9643066813150a98763c1662d3994c",
            "subpath": "g"
        },
        "libstdc++-devel": {
            "version": "15.0.1-0.11.fc42",
            "sha256": "03ff95f02443d71d8088f4cb43f19f38c32871de8d3d7767fb44aa21bc6a8e2e",
            "subpath": "l"
        },
        "libstdc++": {
            "version": "15.0.1-0.11.fc42",
            "sha256": "d598086c3a9a4243a3f43deec43cdc39f5253264b9162fde40f75a5eff162a47",
            "subpath": "l"
        },
    },
    "aarch64": {
        "gcc": {
            "version": "15.0.1-0.11.fc42",
            "sha256": "1cb24402406436c1527ca954ebd8d055337dcba1805795337015e9c4d75e65cc",
            "subpath": "g"
        },
        "gcc-c++": {
            "version": "15.0.1-0.11.fc42",
            "sha256": "5d25d2101e9862480f843c052b76e9f6f0661b2c181e0fad9afe982a78267616",
            "subpath": "g"
        },
        "cpp": {
            "version": "15.0.1-0.11.fc42",
            "sha256": "7ea7088c1a6a4024bf2a14b6d2683ebfa9d19d57ca7460bcd98e991244451e15",
            "subpath": "c"
        },
        "binutils": {
            "version": "2.44-3.fc42",
            "sha256": "13d6e5c3c7dbdf12fa49f9b39074fb0c8cfbcf3e60d3d1f31e4085e90c397937",
            "subpath": "b"
        },
        "glibc-devel": {
            "version": "2.41-1.fc42",
            "sha256": "26a3faae9fa90071c8b57890995a0d2c4ca66b04e4a2cdbbf4ba25ddd00cd8b9",
            "subpath": "g"
        },
        "libstdc++-devel": {
            "version": "15.0.1-0.11.fc42",
            "sha256": "6c33955b9e805987f0f56098c730338c1ff56f761c9ae4f21b30da4c46a6ad7a",
            "subpath": "l"
        },
        "libstdc++": {
            "version": "15.0.1-0.11.fc42",
            "sha256": "d1a70158509f636a43a0c643453751710c368f0921ceaef4b31e67896ac34bed",
            "subpath": "l"
        },
    },
}

def _fedora_gcc_toolchain_impl(repository_ctx):
    """Downloads Fedora RPM packages and creates an isolated GCC toolchain.

    This function creates a complete, self-contained GCC toolchain by downloading
    and extracting essential packages from Fedora repositories, then configuring
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
    base_url_template = "https://download.fedoraproject.org/pub/fedora/linux/releases/{release}/Everything/{arch}/os/Packages/{subpath}/{pkg_name}-{version}.{arch}.rpm"
    download_and_extract_packages(repository_ctx, packages, base_url_template, _FEDORA_RELEASE, rpm_arch, "Fedora {}".format(_FEDORA_RELEASE))

    # Use shared GCC version detection
    gcc_version, gcc_major = detect_gcc_version(repository_ctx)

    # Use shared include directory calculation
    include_dirs = calculate_include_dirs(rpm_arch, gcc_major)

    # Use shared BUILD file generation
    build_content = generate_build_file(gcc_version, include_dirs, rpm_arch)
    repository_ctx.file("BUILD.bazel", build_content)

    # Define Fedora-specific compiler flags
    fedora_flags = {
        "c_flags": [
            "-O2",
            "-g",
            "-pipe",
            "-fstack-protector-strong",
            "-Wpedantic",
        ],
        "cxx_flags": [
            "-O2",
            "-g",
            "-pipe",
            "-fstack-protector-strong",
        ],
        "link_flags": [
            "-Wl,-z,relro",
            "-Wl,-z,now",
        ]
    }

    # Use shared toolchain config generation
    module_names = {
        "module_name": "multi_gcc_toolchain",
        "extension_name": "fedora_gcc_extension",
        "repo_name": "fedora_gcc_repo",
        "distro_name": "fedora"
    }
    repository_ctx.file("cc_toolchain_config.bzl", generate_cc_toolchain_config(module_names, fedora_flags))

# Define the repository rule
fedora_gcc_toolchain = repository_rule(
    implementation = _fedora_gcc_toolchain_impl,
    doc = "Repository rule for Fedora GCC toolchain",
)

def _fedora_gcc_extension_impl(module_ctx):
    """Extension implementation for Fedora GCC toolchain"""
    fedora_gcc_toolchain(name = "fedora_gcc_repo")

fedora_gcc_extension = module_extension(
    implementation = _fedora_gcc_extension_impl,
    doc = "Extension for Fedora GCC toolchain",
)