"""
CentOS GCC Toolchain for Bazel

This extension provides an isolated GCC toolchain built from CentOS RPM packages.
"""

load("//common:toolchain_utils.bzl", "validate_system_requirements", "get_target_architecture",
     "detect_gcc_version", "download_and_extract_packages")

# Configuration
_CENTOS_RELEASE = "9"

# Essential packages for a complete GCC toolchain - organized by architecture
# Note: CentOS uses different package versions and repository structure
_PACKAGES_BY_ARCH = {
    "x86_64": {
        "gcc-toolset-14-gcc": {
            "version": "14.2.1-12.el9",
            "sha256": "206edfb9e83635884bb1b34db1b5015ca7e223109bcf5099648793acc2a70c07",
        },
        "gcc-toolset-14-gcc-c++": {
            "version": "14.2.1-12.el9",
            "sha256": "cdca57094aad8259e5cbba7553bb7f5b82fe877e51230026c2068361a1d367ea",
        },
        "glibc-devel": {
            "version": "2.34-232.el9",
            "sha256": "42e6ad29fc25a5a79635f17be4189950adcddf1e03f3060ab950ae362650c254",
        },
        "glibc-headers": {
            "version": "2.34-232.el9",
            "sha256": "c400735cbe49a6a3f2d7d9a6cbe3d23e528e7ecb42576598b7fe2a5f75b23411",
        },
        "gcc-toolset-14-libstdc++-devel": {
            "version": "14.2.1-12.el9",
            "sha256": "bd637e3eb1ac8bdeca0bea59abb733ba029202dfe367f9ae8749ddcd3469bb1c",
        },
        "kernel-headers": {
            "version": "5.14.0-617.el9",
            "sha256": "8dc4c726537d55bc412733027802d0a0ef57368da044b574f2c921e3b95f6508",
        },
        "gcc-toolset-14-binutils": {
            "version": "2.41-5.el9",
            "sha256": "ff3f18344de9d15ee5c42892779e6ce0aee5fdc081a080b6afd53da8a17efc07",
        },
    },
    "aarch64": {
        "gcc-toolset-14-gcc": {
            "version": "14.2.1-12.el9",
            "sha256": "6a39e23a024641ce50182a59099724cb4c93ccd759816882c806bef1498cf818",
        },
        "gcc-toolset-14-gcc-c++": {
            "version": "14.2.1-12.el9",
            "sha256": "b494c73ff38f98af54e8d3293f38cea033d8a1bd590f477242e1024a710dd4b2",
        },
        "glibc-devel": {
            "version": "2.34-232.el9",
            "sha256": "8e3f3aedb10ca4f2d366cb5becbdf3451d9b133f5ed278000da6f68e1b3f71d4",
        },
        "gcc-toolset-14-libstdc++-devel": {
            "version": "14.2.1-12.el9",
            "sha256": "2380b88a25d3e612008bba55f3634ac83b41aec6080bdc08fed83d6a5df67e49",
        },
        "kernel-headers": {
            "version": "5.14.0-617.el9",
            "sha256": "0f118eeca9c67ad5d9b528502541a37896a76f9ba42dc01195284f43912890fc",
        },
        "gcc-toolset-14-binutils": {
            "version": "2.41-5.el9",
            "sha256": "cb555545d16fff3fbb1ac78aec3d81aca8b84b8b063abcd387ed31754bb45521",
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
    base_url_template = "https://autosd.sig.centos.org/AutoSD-{release}/nightly/repos/AutoSD/compose/AutoSD/{arch}/os/Packages/{pkg_name}-{version}.{arch}.rpm"
    download_and_extract_packages(repository_ctx, packages, base_url_template, _CENTOS_RELEASE, rpm_arch, "CentOS {}".format(_CENTOS_RELEASE))

    # Create symbolic links from standard paths to gcc-toolset-14 paths
    # This allows the standard toolchain logic to work without modification
    gcc_toolset_root = "opt/rh/gcc-toolset-14/root"

    # Create directories and copy essential gcc-toolset-14 components to standard locations
    repository_ctx.execute(["mkdir", "-p", "usr/bin", "usr/lib", "usr/libexec", "usr/include"])

    # Copy GCC internal components (needed for compilation headers like stddef.h)
    repository_ctx.execute([
        "cp", "-r",
        "{}/usr/lib/gcc".format(gcc_toolset_root),
        "usr/lib/gcc"
    ])
    repository_ctx.execute([
        "cp", "-r",
        "{}/usr/libexec/gcc".format(gcc_toolset_root),
        "usr/libexec/gcc"
    ])

    # Copy gcc-toolset-14 headers to standard location
    repository_ctx.execute([
        "bash", "-c",
        "if [ -d {}/usr/include ]; then cp -r {}/usr/include/* usr/include/ 2>/dev/null || true; fi".format(gcc_toolset_root, gcc_toolset_root)
    ])

    # Copy C++ headers from gcc-toolset-14 location to standard location
    repository_ctx.execute([
        "bash", "-c",
        "if [ -d {}/usr/include/c++ ]; then mkdir -p usr/include/c++ && cp -r {}/usr/include/c++/* usr/include/c++/ 2>/dev/null || true; fi".format(gcc_toolset_root, gcc_toolset_root)
    ])

    # Create wrapper scripts for gcc-toolset-14 tools to handle library dependencies
    tools = ["gcc", "g++", "cpp", "ar", "ld", "ld.bfd", "objcopy", "strip", "objdump", "as"]

    for tool in tools:
        # Create a wrapper script that sets LD_LIBRARY_PATH
        wrapper_content = "#!/bin/bash\n"
        wrapper_content += "# Wrapper for {} to ensure libraries are found\n".format(tool)
        wrapper_content += "# Get the directory of this script\n"
        wrapper_content += "SCRIPT_DIR=\"$(dirname \"$(readlink -f \"$0\")\")\"\n"
        wrapper_content += "REPO_ROOT=\"$(dirname \"$(dirname \"$SCRIPT_DIR\")\")\"  # Go up from usr/bin to repo root\n"
        wrapper_content += "TOOLSET_ROOT=\"$REPO_ROOT/{}\"\n".format(gcc_toolset_root)
        wrapper_content += "export LD_LIBRARY_PATH=\"$TOOLSET_ROOT/usr/lib64:$TOOLSET_ROOT/usr/lib:$LD_LIBRARY_PATH\"\n"
        wrapper_content += "exec \"$TOOLSET_ROOT/usr/bin/{}\" \"$@\"\n".format(tool)

        repository_ctx.file("usr/bin/{}".format(tool), wrapper_content, executable=True)

    # Use shared GCC version detection (now that gcc is available at usr/bin/gcc)
    gcc_version, gcc_major = detect_gcc_version(repository_ctx)

    # Use flags passed from the extension (or defaults if none provided)
    centos_flags = {
        "c_flags": getattr(repository_ctx.attr, "c_flags", []),
        "cxx_flags": getattr(repository_ctx.attr, "cxx_flags", []),
        "link_flags": getattr(repository_ctx.attr, "link_flags", []),
    }

    # Use BUILD template instead of generating dynamically
    bazel_cpu = "x86_64" if rpm_arch == "x86_64" else "aarch64"

    # Format flag lists for template substitution
    c_flags_str = ', '.join(['"{}"'.format(flag) for flag in centos_flags.get("c_flags", [])])
    cxx_flags_str = ', '.join(['"{}"'.format(flag) for flag in centos_flags.get("cxx_flags", [])])
    link_flags_str = ', '.join(['"{}"'.format(flag) for flag in centos_flags.get("link_flags", [])])

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
        },
    )

    # Copy shared template instead of generating dynamically
    repository_ctx.template(
        "cc_toolchain_config.bzl",
        Label("@multi_gcc_toolchain//common:cc_toolchain_config.bzl.template"),
        substitutions = {
            "{REPO_NAME}": "multi_gcc_toolchain++centos_gcc_extension+centos_gcc_repo",
            "{DISTRO_NAME}": "centos",
        },
    )

# Define the repository rule
centos_gcc_toolchain = repository_rule(
    implementation = _centos_gcc_toolchain_impl,
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
    doc = "Repository rule for CentOS GCC toolchain",
)

def _centos_gcc_extension_impl(module_ctx):
    """Extension implementation for CentOS GCC toolchain"""
    # Create a separate toolchain for each module
    for i, mod in enumerate(module_ctx.modules):
        # Generate unique name for each module's toolchain
        toolchain_name = "centos_gcc_repo" if i == 0 else "centos_gcc_repo_{}".format(i)

        # Merge flags from all configure tags within this module
        c_flags = []
        cxx_flags = []
        link_flags = []

        for config_tag in mod.tags.configure:
            c_flags.extend(config_tag.c_flags)
            cxx_flags.extend(config_tag.cxx_flags)
            link_flags.extend(config_tag.link_flags)

        centos_gcc_toolchain(
            name = toolchain_name,
            c_flags = c_flags,
            cxx_flags = cxx_flags,
            link_flags = link_flags,
        )

_configure_tag = tag_class(
    attrs = {
        "c_flags": attr.string_list(
            doc = "C compiler flags for the CentOS GCC toolchain",
        ),
        "cxx_flags": attr.string_list(
            doc = "C++ compiler flags for the CentOS GCC toolchain",
        ),
        "link_flags": attr.string_list(
            doc = "Linker flags for the CentOS GCC toolchain",
        ),
    },
    doc = "Configure compiler and linker flags for the CentOS GCC toolchain",
)

centos_gcc_extension = module_extension(
    implementation = _centos_gcc_extension_impl,
    tag_classes = {
        "configure": _configure_tag,
    },
    doc = "Extension for CentOS GCC toolchain",
)
