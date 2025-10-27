"""
AutoSD 9 GCC Toolchain for Bazel

This extension provides an isolated GCC toolchain built from AutoSD 9 (CentOS Stream 9) RPM packages.
"""

load("//common:toolchain_utils.bzl", "validate_system_requirements", "get_target_architecture",
     "detect_gcc_version", "download_and_extract_packages")

# Configuration
_AUTOSD_RELEASE = "9"

# Essential packages for a complete GCC toolchain - organized by architecture
# Note: AutoSD 9 is based on CentOS Stream 9 with GCC 11 and glibc 2.34
_PACKAGES_BY_ARCH = {
    "x86_64": {
        "gcc": {
            "version": "11.5.0-11.el9",
            "sha256": "750debb1d5e6d319df6057dc56b19b8ab9c814c80be5f3576e9a3c960fa007cf",
        },
        "gcc-c++": {
            "version": "11.5.0-11.el9",
            "sha256": "d7d95edd8fca8d5af327eaa141c1d3279440052637666ccafc87c065164fd16e",
        },
        "cpp": {
            "version": "11.5.0-11.el9",
            "sha256": "cfdf4d60773d0924b21c579b830086be01e8139983ec6b1375becbfefe926fb4",
        },
        "binutils": {
            "version": "2.35.2-67.el9",
            "sha256": "1f8dd90e7b2f751fbb3d0273356856ea5321c9e6e7036e0e83d3545e17a15171",
        },
        "glibc-devel": {
            "version": "2.34-237.el9",
            "sha256": "18392260e65abfebdcd53433d75fc2c8d89dd9f479b203856a18b748ba18d9ea",
        },
        "libstdc++-devel": {
            "version": "11.5.0-11.el9",
            "sha256": "f7717e045791df32100738ef74ceb0e83539d0c183cd7be684b8a01c43a72396",
        },
        "libstdc++": {
            "version": "11.5.0-11.el9",
            "sha256": "b17a28146ed5785049f59c22c7c93839f3d8f9c0ea860d8a5657c2d006c09718",
        },
        "kernel-headers": {
            "version": "5.14.0-629.el9",
            "sha256": "944a55cc65a1ba3d56d4c3190f24c25999867d3b21d9262d62a2898e97dc7983",
        },
        "glibc": {
            "version": "2.34-237.el9",
            "sha256": "c80a36acd04d881699c19f8dc9157c7e616a570f5f5915453a38c31574c73089",
        },
        "libgcc": {
            "version": "11.5.0-11.el9",
            "sha256": "405ee42b5de5be323e9e95be3ef806f22ee6d375e15158eb7819895cb163594f",
        },
        "libmpc": {
            "version": "1.2.1-4.el9",
            "sha256": "207e758fadd4779cb11b91a78446f098d0a95b782f30a24c0e998fe08e2561df",
        },
        "gmp": {
            "version": "6.2.0-13.el9",
            "sha256": "b6d592895ccc0fcad6106cd41800cd9d68e5384c418e53a2c3ff2ac8c8b15a33",
        },
        "mpfr": {
            "version": "4.1.0-7.el9",
            "sha256": "179760104aa5a31ca463c586d0f21f380ba4d0eed212eee91bd1ca513e5d7a8d",
        },
        "glibc-headers": {
            "version": "2.34-237.el9",
            "sha256": "9a34165d1a4801010e5cf184490c37fed703a036df08f2cbe811c58f495de579"
        },
    },
}

def _autosd_9_gcc_toolchain_impl(repository_ctx):
    """Downloads AutoSD 9 RPM packages and creates an isolated GCC toolchain.

    This function creates a complete, self-contained GCC toolchain by downloading
    and extracting essential packages from AutoSD 9 repositories, then configuring
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
    # AutoSD 9 uses the same URL structure as AutoSD 10
    base_url_template = "https://autosd.sig.centos.org/AutoSD-{release}/nightly/repos/AutoSD/compose/AutoSD/{arch}/os/Packages/{pkg_name}-{version}.{arch}.rpm"
    download_and_extract_packages(repository_ctx, packages, base_url_template, _AUTOSD_RELEASE, rpm_arch, "AutoSD {}".format(_AUTOSD_RELEASE))


    # ==================================================================================
    # BINUTILS COMPATIBILITY FIXES
    # ==================================================================================
    # Some distributions (e.g., AutoSD 9) don't include /usr/bin/ld as a separate file,
    # only /usr/bin/ld.bfd. Create a symlink to ensure compatibility.
    if repository_ctx.path("usr/bin/ld.bfd").exists and not repository_ctx.path("usr/bin/ld").exists:
        repository_ctx.symlink("usr/bin/ld.bfd", "usr/bin/ld")
        print("Created symlink usr/bin/ld -> usr/bin/ld.bfd for compatibility")

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
            "{GLIBC_CONSTRAINT}": "glibc_2_34_plus",
        },
    )

    # Copy shared template instead of generating dynamically
    repository_ctx.template(
        "cc_toolchain_config.bzl",
        Label("@multi_gcc_toolchain//common:cc_toolchain_config.bzl.template"),
        substitutions = {
            "{REPO_NAME}": repository_ctx.name,
            "{DISTRO_NAME}": "autosd_9",
        },
    )

# Define the repository rule
autosd_9_gcc_toolchain = repository_rule(
    implementation = _autosd_9_gcc_toolchain_impl,
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
    doc = "Repository rule for AutoSD 9 GCC toolchain",
)

def _autosd_9_gcc_extension_impl(module_ctx):
    """Extension implementation for AutoSD 9 GCC toolchain"""
    # Create a separate toolchain for each module
    for i, mod in enumerate(module_ctx.modules):
        # Generate unique name for each module's toolchain
        toolchain_name = "autosd_9_gcc_repo" if i == 0 else "autosd_9_gcc_repo_{}".format(i)

        # Merge flags from all configure tags within this module
        c_flags = []
        cxx_flags = []
        link_flags = []

        for config_tag in mod.tags.configure:
            c_flags.extend(config_tag.c_flags)
            cxx_flags.extend(config_tag.cxx_flags)
            link_flags.extend(config_tag.link_flags)

        autosd_9_gcc_toolchain(
            name = toolchain_name,
            c_flags = c_flags,
            cxx_flags = cxx_flags,
            link_flags = link_flags,
        )

_configure_tag = tag_class(
    attrs = {
        "c_flags": attr.string_list(
            doc = "C compiler flags for the AutoSD 9 GCC toolchain",
        ),
        "cxx_flags": attr.string_list(
            doc = "C++ compiler flags for the AutoSD 9 GCC toolchain",
        ),
        "link_flags": attr.string_list(
            doc = "Linker flags for the AutoSD 9 GCC toolchain",
        ),
    },
    doc = "Configure compiler and linker flags for the AutoSD 9 GCC toolchain",
)

autosd_9_gcc_extension = module_extension(
    implementation = _autosd_9_gcc_extension_impl,
    tag_classes = {
        "configure": _configure_tag,
    },
    doc = "Extension for AutoSD 9 GCC toolchain",
)
