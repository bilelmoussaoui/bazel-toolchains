"""
Host GCC Toolchain for Bazel

This extension provides a GCC toolchain that uses the host system's installed GCC.
No external downloads - uses existing system packages.
"""

load("//common:toolchain_utils.bzl", "get_target_architecture")

def _detect_host_gcc_version(repository_ctx):
    """Detect GCC version from host system (similar to shared detect_gcc_version but for host)."""
    version_result = repository_ctx.execute([
        "bash", "-c",
        "gcc --version | head -1 | grep -o '[0-9]\\+\\.[0-9]\\+\\.[0-9]\\+' | head -1"
    ])

    if version_result.return_code != 0 or not version_result.stdout.strip():
        fail("Failed to parse GCC version from gcc --version output")

    gcc_version = version_result.stdout.strip()
    gcc_major = gcc_version.split('.')[0]
    print("Detected host GCC version: {}".format(gcc_version))

    return gcc_version, gcc_major

def _detect_host_includes(repository_ctx):
    """Detect system include directories."""
    cpp_result = repository_ctx.execute([
        "bash", "-c",
        "echo | gcc -E -Wp,-v - 2>&1 | grep '^ /' | sed 's/^ //'"
    ])

    if cpp_result.return_code != 0:
        fail("Failed to detect system include directories")

    system_includes = [line.strip() for line in cpp_result.stdout.strip().split('\n') if line.strip()]
    print("Detected system includes: {}".format(system_includes))

    return system_includes

def _host_gcc_toolchain_impl(repository_ctx):
    """Creates a GCC toolchain using the host system's installed GCC.

    This function detects the system GCC installation and creates a toolchain
    configuration that uses the host's compiler, headers, and libraries.
    """

    # Validate that required tools are available on the host
    for tool in ["gcc", "g++", "ld", "ar", "strip"]:
        result = repository_ctx.execute(["which", tool])
        if result.return_code != 0:
            fail("Required tool '{}' is not available in PATH on the host system. Please install GCC development tools.".format(tool))

    # Use shared architecture detection
    rpm_arch = get_target_architecture(repository_ctx)

    # Use shared GCC version detection (but skip the dependency on extracted files)
    gcc_version, gcc_major = _detect_host_gcc_version(repository_ctx)

    # Detect system include directories
    system_includes = _detect_host_includes(repository_ctx)

    # For host toolchain, we'll use a simplified approach for BUILD file
    # since the shared generate_build_file expects RPM-style extracted files
    build_content = _generate_host_build_file(gcc_version, rpm_arch)
    repository_ctx.file("BUILD.bazel", build_content)

    # Define host-specific compiler flags
    host_flags = {
        "c_flags": [
            # Host system may have its own preferred flags
        ],
        "cxx_flags": [
            # Host system may have its own preferred flags
        ],
        "link_flags": [
            # Host system may have its own preferred flags
        ]
    }

    # Use shared toolchain config generation
    module_names = {
        "module_name": "multi_gcc_toolchain",
        "extension_name": "host_gcc_extension",
        "repo_name": "host_gcc_repo",
        "distro_name": "host"
    }

    # Try to use shared cc_toolchain_config generation with host-specific modifications
    # For now, we'll keep the custom host version since the shared one expects RPM-style paths
    config_content = _generate_host_cc_toolchain_config(module_names, host_flags, system_includes, rpm_arch, gcc_version)
    repository_ctx.file("cc_toolchain_config.bzl", config_content)

def _generate_host_build_file(gcc_version, arch):
    """Generate BUILD.bazel content for host toolchain."""

    bazel_cpu = "x86_64" if arch == "x86_64" else "aarch64"

    return '''load(":cc_toolchain_config.bzl", "cc_toolchain_config")

package(default_visibility = ["//visibility:public"])

# The host toolchain uses system tools directly
filegroup(
    name = "all_files",
    srcs = [],
)

filegroup(
    name = "compiler_files",
    srcs = [],
)

filegroup(
    name = "linker_files",
    srcs = [],
)

filegroup(
    name = "ar_files",
    srcs = [],
)

filegroup(
    name = "objcopy_files",
    srcs = [],
)

filegroup(
    name = "strip_files",
    srcs = [],
)

filegroup(
    name = "empty",
    srcs = [],
)

# Toolchain configuration
cc_toolchain_config(
    name = "gcc_toolchain_config",
    gcc_version = "{gcc_version}",
    target_arch = "{arch}",
)

# The actual toolchain
cc_toolchain(
    name = "gcc_toolchain",
    all_files = ":empty",
    ar_files = ":empty",
    compiler_files = ":empty",
    dwp_files = ":empty",
    linker_files = ":empty",
    objcopy_files = ":empty",
    strip_files = ":empty",
    supports_param_files = 1,
    toolchain_config = ":gcc_toolchain_config",
)

# Toolchain definition for registration
toolchain(
    name = "gcc_toolchain_linux_{arch}",
    exec_compatible_with = [
        "@platforms//os:linux",
        "@platforms//cpu:{bazel_cpu}",
    ],
    target_compatible_with = [
        "@platforms//os:linux",
        "@platforms//cpu:{bazel_cpu}",
    ],
    toolchain = ":gcc_toolchain",
    toolchain_type = "@bazel_tools//tools/cpp:toolchain_type",
)
'''.format(gcc_version=gcc_version, arch=arch, bazel_cpu=bazel_cpu)

def _generate_host_cc_toolchain_config(module_names, host_flags, system_includes, arch, gcc_version):
    """Generate cc_toolchain_config.bzl for host toolchain."""

    # Prepare flags using same logic as shared utilities
    if not host_flags:
        host_flags = {"c_flags": [], "cxx_flags": [], "link_flags": []}

    c_flags_str = ""
    if host_flags.get("c_flags"):
        quoted_flags = ['"{}"'.format(flag) for flag in host_flags["c_flags"]]
        c_flags_str = ",\n".join([""] + quoted_flags)

    cxx_flags_str = ""
    if host_flags.get("cxx_flags"):
        quoted_flags = ['"{}"'.format(flag) for flag in host_flags["cxx_flags"]]
        cxx_flags_str = ",\n".join([""] + quoted_flags)

    link_flags_str = ""
    if host_flags.get("link_flags"):
        quoted_flags = ['"{}"'.format(flag) for flag in host_flags["link_flags"]]
        link_flags_str = ",\n".join([""] + quoted_flags)

    # Format system includes for Bazel
    include_dirs_list = []
    for include_dir in system_includes:
        include_dirs_list.append('"{}"'.format(include_dir))
    include_dirs_str = "[" + ", ".join(include_dirs_list) + "]"

    return '''
load("@bazel_tools//tools/cpp:cc_toolchain_config_lib.bzl",
     "feature", "flag_group", "flag_set", "tool_path")
load("@bazel_tools//tools/build_defs/cc:action_names.bzl", "ACTION_NAMES")

def _impl(ctx):
    tool_paths = [
        tool_path(name = "gcc", path = "/usr/bin/gcc"),
        tool_path(name = "g++", path = "/usr/bin/g++"),
        tool_path(name = "ld", path = "/usr/bin/ld"),
        tool_path(name = "ar", path = "/usr/bin/ar"),
        tool_path(name = "cpp", path = "/usr/bin/cpp"),
        tool_path(name = "gcov", path = "/usr/bin/gcov"),
        tool_path(name = "nm", path = "/usr/bin/nm"),
        tool_path(name = "objdump", path = "/usr/bin/objdump"),
        tool_path(name = "strip", path = "/usr/bin/strip"),
    ]

    # Compiler flags for host system (similar to shared utilities structure)
    default_compile_flags = feature(
        name = "default_compile_flags",
        enabled = True,
        flag_sets = [
            flag_set(
                actions = [ACTION_NAMES.c_compile],
                flag_groups = [
                    flag_group(
                        flags = [
                            "-Wall",
                            "-Wextra"{c_flags_str},
                        ],
                    ),
                ],
            ),
            flag_set(
                actions = [ACTION_NAMES.cpp_compile],
                flag_groups = [
                    flag_group(
                        flags = [
                            "-Wall",
                            "-Wextra"{cxx_flags_str},
                        ],
                    ),
                ],
            ),
        ],
    )

    default_link_flags = feature(
        name = "default_link_flags",
        enabled = True,
        flag_sets = [
            flag_set(
                actions = [
                    ACTION_NAMES.cpp_link_executable,
                    ACTION_NAMES.cpp_link_dynamic_library,
                ],
                flag_groups = [
                    flag_group(
                        flags = [
                            "-lstdc++",
                            "-lm"{link_flags_str},
                        ],
                    ),
                ],
            ),
        ],
    )

    return cc_common.create_cc_toolchain_config_info(
        ctx = ctx,
        features = [default_compile_flags, default_link_flags],
        cxx_builtin_include_directories = {include_dirs_str},
        toolchain_identifier = "host-gcc-{{}}".format(ctx.attr.gcc_version),
        host_system_name = "local",
        target_system_name = "local",
        target_cpu = ctx.attr.target_arch,
        target_libc = "glibc",
        compiler = "gcc",
        abi_version = "unknown",
        abi_libc_version = "unknown",
        tool_paths = tool_paths,
    )

cc_toolchain_config = rule(
    implementation = _impl,
    attrs = {{
        "gcc_version": attr.string(mandatory = True),
        "target_arch": attr.string(mandatory = True),
    }},
    provides = [CcToolchainConfigInfo],
)
'''.format(
        c_flags_str=c_flags_str,
        cxx_flags_str=cxx_flags_str,
        link_flags_str=link_flags_str,
        include_dirs_str=include_dirs_str
    )

# Define the repository rule
host_gcc_toolchain = repository_rule(
    implementation = _host_gcc_toolchain_impl,
    doc = "Repository rule for host GCC toolchain",
)

def _host_gcc_extension_impl(module_ctx):
    """Extension implementation for host GCC toolchain"""
    host_gcc_toolchain(name = "host_gcc_repo")

host_gcc_extension = module_extension(
    implementation = _host_gcc_extension_impl,
    doc = "Extension for host GCC toolchain",
)