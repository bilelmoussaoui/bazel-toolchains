"""
AutoSD 10 GCC Toolchain for Bazel

This extension provides an isolated GCC toolchain built from AutoSD 10 (CentOS Stream 10) RPM packages.
"""

load("//common:toolchain_utils.bzl", "validate_system_requirements", "get_target_architecture",
     "detect_gcc_version", "download_and_extract_packages")

# Configuration
_AUTOSD_RELEASE = "10"

# Essential packages for a complete GCC toolchain - organized by architecture
# Note: AutoSD 10 uses CentOS Stream 10 package versions and repository structure
_PACKAGES_BY_ARCH = {
    "x86_64": {
        "gcc": {
            "version": "14.3.1-2.3.el10",
            "sha256": "ece43ba0e34ff0513dfdd13fc41355c88f28b7e4f675a9c1e16c43f3efdcda64",
        },
        "gcc-c++": {
            "version": "14.3.1-2.3.el10",
            "sha256": "d5bee4d8b00c8dde8e826ec160e39de4424e62cf713a9ba18d92a23b87917c54",
        },
        "cpp": {
            "version": "14.3.1-2.3.el10",
            "sha256": "6a23043713d8027c658133310b6d878a86af26e36ad05328ec0f405f1facff1b",
        },
        "binutils": {
            "version": "2.41-58.el10",
            "sha256": "2deab9e4aa6fe34dea2d6e312c4a6d48a02288e627e94594b497397365e50712",
        },
        "glibc-devel": {
            "version": "2.39-69.el10",
            "sha256": "c0059b0f12ba7168d71ed53620732107614e7dfb660aa9d14f763bc48006f5b7",
        },
        "libstdc++-devel": {
            "version": "14.3.1-2.3.el10",
            "sha256": "ad622697cf23df121db3d6ba1133a6f37a122038e8d447813f3c8645b872446c",
        },
        "libstdc++": {
            "version": "14.3.1-2.3.el10",
            "sha256": "c0868f811d6b8a9cbc77f6c93dbdd1114e21699edf578eea083ee27c2a6b0b46",
        },
        "kernel-headers": {
            "version": "6.12.0-145.el10",
            "sha256": "411c251dec78e7c927ae022ec2bb14bd085e4672aafa0ba2e2bd51a82f6fd118",
        },
        "glibc": {
            "version": "2.39-69.el10",
            "sha256": "8f7bc6fc34babf8609af6ac13953babcff88d819617ebb046863aa28a5db18d3",
        },
        "libgcc": {
            "version": "14.3.1-2.3.el10",
            "sha256": "96a64df25761b109296eeed6bf14f0b827de986956a47d25078d0c04340a5b19",
        },
        "libmpc": {
            "version": "1.3.1-7.el10",
            "sha256": "daaa73a35dfe21a8201581e333b79ccd296ae87a93f9796ba522e58edc23777c",
        },
        "gmp": {
            "version": "6.2.1-12.el10",
            "sha256": "6678824b5d45f9b66e8bfeb8f32736e0d710e3b38531a85548f55702d96b63a8",
        },
        "mpfr": {
            "version": "4.2.1-5.el10",
            "sha256": "a70bc74bde41c17df2d789ffc2a3c3034e1203c6a6c50e6133994f130d23e6bb",
        },
    },
    "aarch64": {
        "gcc": {
            "version": "14.3.1-2.3.el10",
            "sha256": "4340f6ef5e701b218e7f04a82828dedb813bab03b76c92d40da2caac373f1f57",
        },
        "gcc-c++": {
            "version": "14.3.1-2.3.el10",
            "sha256": "6112cf4c998f17ed05c034bcabcad6a630735d75586619fb186fd1da2c0a066e",
        },
        "cpp": {
            "version": "14.3.1-2.3.el10",
            "sha256": "b1a2a2b5937b95baa95588c3938d64829c71abf9328d2697e4560aa4a240137f",
        },
        "binutils": {
            "version": "2.41-58.el10",
            "sha256": "5cda10bb09dba160cbfd8f629eb308bcb203df2468821afb1c2b51aed45cd8a7",
        },
        "glibc-devel": {
            "version": "2.39-69.el10",
            "sha256": "2eaad4365509547e1519ce55cd2c7e8d7b5cc42ef784c1feaddbbe547f385211",
        },
        "libstdc++-devel": {
            "version": "14.3.1-2.3.el10",
            "sha256": "0b4482a4b1134da4f4bbd5bc9552d4e6fe97419df13533e07e2bbe72836b6fb5",
        },
        "libstdc++": {
            "version": "14.3.1-2.3.el10",
            "sha256": "9204d7de574e0e1b16ebf114dcd7922c59a33ae1568b72ec6e49d1d02dbf06f3",
        },
        "kernel-headers": {
            "version": "6.12.0-145.el10",
            "sha256": "ed22f45ff663286a92e5a8d97ec3216ef1c4c01084936bfe29d7d31009ef34ba",
        },
        "glibc": {
            "version": "2.39-69.el10",
            "sha256": "37f39e57d65bc469c49ec3614541fe8b20d16202e1770577e03e9b06cab23ef8",
        },
        "libgcc": {
            "version": "14.3.1-2.3.el10",
            "sha256": "392c0f450ffb7d91f405f71b8c4ea531aaf5223542d7deced2602d70b4644a22",
        },
        "libmpc": {
            "version": "1.3.1-7.el10",
            "sha256": "bb46a7465559a26c085bf1c02f0764332430a6c1b8fb3f08c8cee184e3d1f02a",
        },
        "gmp": {
            "version": "6.2.1-12.el10",
            "sha256": "9bbe58df2a29320daf9b4c36305fcc7f781ab0bdd486736c6d8c685838141a41",
        },
        "mpfr": {
            "version": "4.2.1-5.el10",
            "sha256": "30067f4b30700a4dbe21ee5ce458f3a6ab41b7a419b8be572e21967316877b10",
        },
    },
}

def _autosd_10_gcc_toolchain_impl(repository_ctx):
    """Downloads AutoSD 10 RPM packages and creates an isolated GCC toolchain.

    This function creates a complete, self-contained GCC toolchain by downloading
    and extracting essential packages from AutoSD 10 repositories, then configuring
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
    # AutoSD 10 uses CentOS Stream 10 URL structure - no subpath needed
    base_url_template = "https://download.autosd.sig.centos.org/AutoSD-{release}/nightly/repos/AutoSD/compose/AutoSD/{arch}/os/Packages/{pkg_name}-{version}.{arch}.rpm"
    download_and_extract_packages(repository_ctx, packages, base_url_template, _AUTOSD_RELEASE, rpm_arch, "AutoSD {}".format(_AUTOSD_RELEASE))

    # Use shared GCC version detection
    gcc_version, gcc_major = detect_gcc_version(repository_ctx)

    # Use flags passed from the extension (or defaults if none provided)
    autosd_flags = {
        "c_flags": getattr(repository_ctx.attr, "c_flags", []),
        "cxx_flags": getattr(repository_ctx.attr, "cxx_flags", []),
        "link_flags": getattr(repository_ctx.attr, "link_flags", []),
    }

    # Use BUILD template instead of generating dynamically
    bazel_cpu = "x86_64" if rpm_arch == "x86_64" else "aarch64"

    # Format flag lists for template substitution
    c_flags_str = ', '.join(['"{}"'.format(flag) for flag in autosd_flags.get("c_flags", [])])
    cxx_flags_str = ', '.join(['"{}"'.format(flag) for flag in autosd_flags.get("cxx_flags", [])])
    link_flags_str = ', '.join(['"{}"'.format(flag) for flag in autosd_flags.get("link_flags", [])])

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
            "{GLIBC_CONSTRAINT}": "glibc_2_39_plus",
        },
    )

    # Copy shared template instead of generating dynamically
    repository_ctx.template(
        "cc_toolchain_config.bzl",
        Label("@multi_gcc_toolchain//common:cc_toolchain_config.bzl.template"),
        substitutions = {
            "{REPO_NAME}": repository_ctx.name,
            "{DISTRO_NAME}": "autosd_10",
        },
    )

# Define the repository rule
autosd_10_gcc_toolchain = repository_rule(
    implementation = _autosd_10_gcc_toolchain_impl,
    attrs = {
        "c_flags": attr.string_list(
            doc = "C compiler flags for the toolchain",
            default = ["-O2", "-g", "-pipe", "-Wall", "-Werror=format-security"],
        ),
        "cxx_flags": attr.string_list(
            doc = "C++ compiler flags for the toolchain",
            default = ["-O2", "-g", "-pipe", "-Wall", "-Werror=format-security"],
        ),
        "link_flags": attr.string_list(
            doc = "Linker flags for the toolchain",
            default = ["-Wl,-z,relro", "-Wl,-z,now"],
        ),
    },
    doc = "Repository rule for AutoSD 10 GCC toolchain",
)

def _autosd_10_gcc_extension_impl(module_ctx):
    """Extension implementation for AutoSD 10 GCC toolchain"""
    # Create a separate toolchain for each module
    for i, mod in enumerate(module_ctx.modules):
        # Generate unique name for each module's toolchain
        toolchain_name = "autosd_10_gcc_repo" if i == 0 else "autosd_10_gcc_repo_{}".format(i)

        # Merge flags from all configure tags within this module
        c_flags = []
        cxx_flags = []
        link_flags = []

        for config_tag in mod.tags.configure:
            c_flags.extend(config_tag.c_flags)
            cxx_flags.extend(config_tag.cxx_flags)
            link_flags.extend(config_tag.link_flags)

        autosd_10_gcc_toolchain(
            name = toolchain_name,
            c_flags = c_flags,
            cxx_flags = cxx_flags,
            link_flags = link_flags,
        )

_configure_tag = tag_class(
    attrs = {
        "c_flags": attr.string_list(
            doc = "C compiler flags for the AutoSD 10 GCC toolchain",
        ),
        "cxx_flags": attr.string_list(
            doc = "C++ compiler flags for the AutoSD 10 GCC toolchain",
        ),
        "link_flags": attr.string_list(
            doc = "Linker flags for the AutoSD 10 GCC toolchain",
        ),
    },
    doc = "Configure compiler and linker flags for the AutoSD 10 GCC toolchain",
)

autosd_10_gcc_extension = module_extension(
    implementation = _autosd_10_gcc_extension_impl,
    tag_classes = {
        "configure": _configure_tag,
    },
    doc = "Extension for AutoSD 10 GCC toolchain",
)
