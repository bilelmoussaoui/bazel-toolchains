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
            "version": "14.3.1-2.1.el10",
            "sha256": "3e6df20e46bc865078ea82707459405863f0969f82f3e7bc1f59eafa5acbf47d",
        },
        "gcc-c++": {
            "version": "14.3.1-2.1.el10",
            "sha256": "59f34694a0729f483e875bb57974fcd49afb09690edba1377f991fb0a57ae0b9",
        },
        "cpp": {
            "version": "14.3.1-2.1.el10",
            "sha256": "3e162eb077cc33d8664a97b9c45c314e64ff06d7821a354b7a6782cb41266283",
        },
        "binutils": {
            "version": "2.41-58.el10",
            "sha256": "2deab9e4aa6fe34dea2d6e312c4a6d48a02288e627e94594b497397365e50712",
        },
        "glibc-devel": {
            "version": "2.39-65.el10",
            "sha256": "9f9dac005fe4a0c6d9c9d1a61c5b899873dd693bf975e458e99a2faef98ef4dc",
        },
        "libstdc++-devel": {
            "version": "14.3.1-2.1.el10",
            "sha256": "ba6188f734d3790b4eb103eea64680d4488d093bedfcc861dae6c20e77897576",
        },
        "libstdc++": {
            "version": "14.3.1-2.1.el10",
            "sha256": "7354b93fde7d2048cee214534462f5d01fb6f772cc80b3740296dd54b2b551e6",
        },
        "kernel-headers": {
            "version": "6.12.0-135.el10",
            "sha256": "54d5e6870faae2510995ac982421c12ee19b610682de15bc3ddb6465ebf576a3",
        },
        "glibc": {
            "version": "2.39-65.el10",
            "sha256": "03f6918fdf323779382a549e62f853f5e5d8ecafacf9f992fe362e9a86886616",
        },
        "libgcc": {
            "version": "14.3.1-2.1.el10",
            "sha256": "7ac815d3fff13c6254f82c4703e1f97063bf6246a8b41c34eb96d58d42f3462b",
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
            "version": "14.3.1-2.1.el10",
            "sha256": "7bc956fbce76bd85659de562e0d7c32d2938eeec82dd1aa2679a8e3670fd177c",
        },
        "gcc-c++": {
            "version": "14.3.1-2.1.el10",
            "sha256": "6774dbdc312d7b9a1c8dff3901d4e8c467da6d1a9df501f3fda1a829040aa665",
        },
        "cpp": {
            "version": "14.3.1-2.1.el10",
            "sha256": "ce16b5946d6a4bdd1bf06d1ef44753449425facbf522c32cb2223e7c222305b4",
        },
        "binutils": {
            "version": "2.41-58.el10",
            "sha256": "5cda10bb09dba160cbfd8f629eb308bcb203df2468821afb1c2b51aed45cd8a7",
        },
        "glibc-devel": {
            "version": "2.39-65.el10",
            "sha256": "dfb688da246848a7a8e38be59b1e828794e190ca14a4a168ed215e20ff963832",
        },
        "libstdc++-devel": {
            "version": "14.3.1-2.1.el10",
            "sha256": "2315d11ff83989759d92115774924524a8bfa880daa3357d9155ed52d8578a70",
        },
        "libstdc++": {
            "version": "14.3.1-2.1.el10",
            "sha256": "f5040f18ff5ad47dd7c39b08d82172c6fb69c37590c5a01fba3cfa294698f92c",
        },
        "kernel-headers": {
            "version": "6.12.0-135.el10",
            "sha256": "5a75e7fd8fc9c5eb8c98c4403b173716d8e7c551c30d8b02a4ae0b9b3f2f6c56",
        },
        "glibc": {
            "version": "2.39-65.el10",
            "sha256": "72b4fed5b009f3afff32005c6720f334fad8e068225832ddeba15c9c2ea78034",
        },
        "libgcc": {
            "version": "14.3.1-2.1.el10",
            "sha256": "9ba86ec9a341cb262d094c06f0759a2aae1e34c00e8d3a5c0821d40afe3bf598",
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
    base_url_template = "https://autosd.sig.centos.org/AutoSD-{release}/nightly/repos/AutoSD/compose/AutoSD/{arch}/os/Packages/{pkg_name}-{version}.{arch}.rpm"
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
