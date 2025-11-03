"""
Fedora GCC Toolchain for Bazel

This extension provides an isolated GCC toolchain built from Fedora RPM packages.
"""

load("//common:toolchain_utils.bzl", "validate_system_requirements", "get_target_architecture",
     "detect_gcc_version", "download_and_extract_packages")

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
        "kernel-headers": {
            "version": "6.14.0-63.fc42",
            "sha256": "253b4aa5bd18ca9798b9c631941d1a6478c22d2f91163a1a1fe740f280a3a0aa",
            "subpath": "k"
        },
        "glibc": {
            "version": "2.41-1.fc42",
            "sha256": "6584cd3ac8fcffe7783c8f53bc4cb2907ab3c2ace3a34d14fe93e90d75509f50",
            "subpath": "g"
        },
        "libgcc": {
            "version": "15.0.1-0.11.fc42",
            "sha256": "d122eac0f888d3aaf35ffc214e00e522b8c8264f4d9024f24be1365ba8dd903f",
            "subpath": "l"
        },
        "libmpc": {
            "version": "1.3.1-7.fc42",
            "sha256": "13f4ae2bebbbe144714f4dc74bcd01dde9e667bff8cd133915f2170a04ad553d",
            "subpath": "l"
        },
        "gmp": {
            "version": "6.3.0-4.fc42",
            "sha256": "1193ba8d39771dc2ff3798c14515ffb9952c0007b529374b24caa8c22aed4493",
            "subpath": "g"
        },
        "mpfr": {
            "version": "4.2.2-1.fc42",
            "sha256": "d0559913dac8fe29ef627859c15e609de6de1122984b3f901400fc77ef7acd4e",
            "subpath": "m"
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
        "kernel-headers": {
            "version": "6.14.0-63.fc42",
            "sha256": "78d69dc4c0fb7c30f1fec3f42344355527ef4061d1729d9b5c184c6ee3e97cda",
            "subpath": "k"
        },
        "glibc": {
            "version": "2.41-1.fc42",
            "sha256": "66bf46511f945ef210cf8d364170f9c64f9b2788db76aedaf9094dd97edffdfc",
            "subpath": "g"
        },
        "libgcc": {
            "version": "15.0.1-0.11.fc42",
            "sha256": "8260a420b69d22b039449d33bd63aeb498574a94b885b4e69556985df64adb11",
            "subpath": "l"
        },
        "libmpc": {
            "version": "1.3.1-7.fc42",
            "sha256": "51940f125f3dca505051490141a645112d7bb72abe17681f173f3edcebb71886",
            "subpath": "l"
        },
        "gmp": {
            "version": "6.3.0-4.fc42",
            "sha256": "ba667916b37c33c1cfd7ade6e63a7fcce04ef1da4e7387180b5397f1be10b230",
            "subpath": "g"
        },
        "mpfr": {
            "version": "4.2.2-1.fc42",
            "sha256": "e5277bf2d5e9324fdb9844581b4869d120d0046507340b434e381fe868ee50c1",
            "subpath": "m"
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

    # Use flags passed from the extension (or defaults if none provided)
    fedora_flags = {
        "c_flags": getattr(repository_ctx.attr, "c_flags", []),
        "cxx_flags": getattr(repository_ctx.attr, "cxx_flags", []),
        "link_flags": getattr(repository_ctx.attr, "link_flags", []),
    }

    # Use BUILD template instead of generating dynamically
    bazel_cpu = "x86_64" if rpm_arch == "x86_64" else "aarch64"

    # Format flag lists for template substitution
    c_flags_str = ', '.join(['"{}"'.format(flag) for flag in fedora_flags.get("c_flags", [])])
    cxx_flags_str = ', '.join(['"{}"'.format(flag) for flag in fedora_flags.get("cxx_flags", [])])
    link_flags_str = ', '.join(['"{}"'.format(flag) for flag in fedora_flags.get("link_flags", [])])

    repository_ctx.template(
        "BUILD.bazel",
        Label("@multi_gcc_toolchain//common:BUILD.bazel.template"),
        substitutions = {
            "{GCC_VERSION}": gcc_version,
            "{GCC_MAJOR}": gcc_major,
            "{TARGET_ARCH}": rpm_arch,
            "{BAZEL_CPU}": bazel_cpu,
            "{C_FLAGS}": c_flags_str,
            "{CXX_FLAGS}": cxx_flags_str,
            "{LINK_FLAGS}": link_flags_str,
            "{GLIBC_CONSTRAINT}": "glibc_2_41_plus",
        },
    )

    # Copy shared template instead of generating dynamically
    repository_ctx.template(
        "cc_toolchain_config.bzl",
        Label("@multi_gcc_toolchain//common:cc_toolchain_config.bzl.template"),
        substitutions = {
            "{REPO_NAME}": repository_ctx.name,
            "{DISTRO_NAME}": "fedora",
        },
    )

# Define the repository rule
fedora_gcc_toolchain = repository_rule(
    implementation = _fedora_gcc_toolchain_impl,
    attrs = {
        "c_flags": attr.string_list(
            doc = "C compiler flags for the toolchain",
            default = ["-O2", "-g", "-pipe", "-fstack-protector-strong", "-Wpedantic"],
        ),
        "cxx_flags": attr.string_list(
            doc = "C++ compiler flags for the toolchain",
            default = ["-O2", "-g", "-pipe", "-fstack-protector-strong"],
        ),
        "link_flags": attr.string_list(
            doc = "Linker flags for the toolchain",
            default = ["-Wl,-z,relro", "-Wl,-z,now"],
        ),
    },
    doc = "Repository rule for Fedora GCC toolchain",
)

def _fedora_gcc_extension_impl(module_ctx):
    """Extension implementation for Fedora GCC toolchain"""
    # Default flags from the repository rule
    default_c_flags = ["-O2", "-g", "-pipe", "-fstack-protector-strong", "-Wpedantic"]
    default_cxx_flags = ["-O2", "-g", "-pipe", "-fstack-protector-strong"]
    default_link_flags = ["-Wl,-z,relro", "-Wl,-z,now"]

    # Create a separate toolchain for each module
    for i, mod in enumerate(module_ctx.modules):
        # Generate unique name for each module's toolchain
        toolchain_name = "fedora_gcc_repo" if i == 0 else "fedora_gcc_repo_{}".format(i)

        # Merge flags from all configure tags within this module
        c_flags = []
        cxx_flags = []
        link_flags = []
        replace_mode = False

        for config_tag in mod.tags.configure:
            if config_tag.replace:
                replace_mode = True
            c_flags.extend(config_tag.c_flags)
            cxx_flags.extend(config_tag.cxx_flags)
            link_flags.extend(config_tag.link_flags)

        # If not in replace mode, prepend defaults
        if not replace_mode:
            c_flags = default_c_flags + c_flags
            cxx_flags = default_cxx_flags + cxx_flags
            link_flags = default_link_flags + link_flags
        # If in replace mode but no flags provided, use defaults
        else:
            if not c_flags:
                c_flags = default_c_flags
            if not cxx_flags:
                cxx_flags = default_cxx_flags
            if not link_flags:
                link_flags = default_link_flags

        fedora_gcc_toolchain(
            name = toolchain_name,
            c_flags = c_flags,
            cxx_flags = cxx_flags,
            link_flags = link_flags,
        )

_configure_tag = tag_class(
    attrs = {
        "c_flags": attr.string_list(
            doc = "C compiler flags for the Fedora GCC toolchain",
        ),
        "cxx_flags": attr.string_list(
            doc = "C++ compiler flags for the Fedora GCC toolchain",
        ),
        "link_flags": attr.string_list(
            doc = "Linker flags for the Fedora GCC toolchain",
        ),
        "replace": attr.bool(
            doc = "If True, replace default flags. If False (default), append to default flags.",
            default = False,
        ),
    },
    doc = "Configure compiler and linker flags for the Fedora GCC toolchain",
)

fedora_gcc_extension = module_extension(
    implementation = _fedora_gcc_extension_impl,
    tag_classes = {
        "configure": _configure_tag,
    },
    doc = "Extension for Fedora GCC toolchain",
)