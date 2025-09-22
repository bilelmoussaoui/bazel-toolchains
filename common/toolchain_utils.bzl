"""
Shared utilities for GCC toolchain implementations.

This module contains common code used by both Fedora and CentOS toolchain extensions.
"""

def validate_system_requirements(repository_ctx):
    """Validate that required system tools are available.

    Args:
        repository_ctx: The repository context provided by Bazel
    """
    # Early validation of required system tools
    for tool in ["rpm2cpio", "cpio", "bash", "grep"]:
        result = repository_ctx.execute(["which", tool])
        if result.return_code != 0:
            fail("Required tool '{}' is not available in PATH. Please install it before using this toolchain.".format(tool))

    # Validate rpm2cpio specifically works
    rpm2cpio_test = repository_ctx.execute(["rpm2cpio", "--help"])
    if rpm2cpio_test.return_code != 0:
        fail("rpm2cpio tool is not working properly. Please ensure rpm2cpio is installed and functional.")

def get_target_architecture(repository_ctx):
    """Get the target architecture, mapping Bazel arch names to RPM arch names.

    Args:
        repository_ctx: The repository context provided by Bazel

    Returns:
        String: The RPM architecture name (x86_64 or aarch64)
    """
    # Map Bazel architecture to RPM architecture
    arch_mapping = {
        "amd64": "x86_64",
        "x86_64": "x86_64",
        "arm64": "aarch64",
        "aarch64": "aarch64",
    }

    bazel_arch = repository_ctx.os.arch
    rpm_arch = arch_mapping.get(bazel_arch, bazel_arch)

    if rpm_arch not in ["x86_64", "aarch64"]:
        fail("Unsupported architecture: {}. Only x86_64 and aarch64 are supported.".format(rpm_arch))

    return rpm_arch

def detect_gcc_version(repository_ctx):
    """Detect GCC version from extracted files.

    Args:
        repository_ctx: The repository context provided by Bazel

    Returns:
        Tuple: (gcc_version, gcc_major) where gcc_version is full version and gcc_major is major version
    """
    # Detect GCC version from the extracted files
    gcc_version_result = repository_ctx.execute([
        "bash", "-c",
        "./usr/bin/gcc --version | head -1 | grep -o '[0-9]\\+\\.[0-9]\\+\\.[0-9]\\+' | head -1"
    ])

    if gcc_version_result.return_code == 0 and gcc_version_result.stdout.strip():
        gcc_version = gcc_version_result.stdout.strip()
        # Remove any extra whitespace or newlines
        gcc_version = gcc_version.replace('\n', '').replace('\r', '').strip()
        if not gcc_version:
            fail("Failed to detect GCC version: empty version string")
    else:
        fail("Failed to detect GCC version from extracted toolchain. Command failed with: {}".format(
            gcc_version_result.stderr if gcc_version_result.stderr else "No error output"
        ))

    gcc_major = gcc_version.split('.')[0]
    print("Detected GCC version: {}".format(gcc_version))

    return gcc_version, gcc_major

def calculate_include_dirs(rpm_arch, gcc_major):
    """Calculate include directories for the toolchain.

    Args:
        rpm_arch: Target architecture (x86_64 or aarch64)
        gcc_major: GCC major version

    Returns:
        List of include directory paths
    """
    return [
        "usr/lib/gcc/{}-redhat-linux/{}/include".format(rpm_arch, gcc_major),
        "usr/include",
        "usr/include/c++/{}".format(gcc_major),
        "usr/include/c++/{}/{}-redhat-linux".format(gcc_major, rpm_arch),
        "usr/include/c++/{}/backward".format(gcc_major),
    ]

def download_and_extract_packages(repository_ctx, packages, base_url_template, release, rpm_arch, repo_name):
    """Download and extract RPM packages.

    Args:
        repository_ctx: The repository context provided by Bazel
        packages: Dictionary of package info
        base_url_template: URL template for downloads (with placeholders)
        release: Distribution release version
        rpm_arch: Target architecture
        repo_name: Repository name for error messages
    """
    print("Downloading {} toolchain for {}".format(repo_name, rpm_arch))

    for package_name, info in packages.items():
        version = info["version"]
        subpath = info.get("subpath", "")
        sha256 = info.get("sha256", "")

        # Format the URL using the template
        rpm_url = base_url_template.format(
            release = release,
            arch = rpm_arch,
            subpath = subpath,
            pkg_name = package_name,
            version = version,
        )

        rpm_filename = "{}.rpm".format(package_name)

        print("Downloading: {}".format(rpm_url))
        download_result = repository_ctx.download(
            url = rpm_url,
            output = rpm_filename,
            sha256 = sha256 if sha256 != "placeholder_sha256_for_{}".format(package_name.replace("-", "_")) else "",
        )

        # Verify download succeeded
        if not download_result.success:
            fail("Failed to download {}: URL may be invalid or package version may not exist".format(rpm_url))

        # Extract RPM using rpm2cpio and cpio
        result = repository_ctx.execute([
            "bash", "-c",
            "rpm2cpio {} | cpio -idmv".format(rpm_filename)
        ])

        if result.return_code != 0:
            fail("Failed to extract {}: {}".format(rpm_filename, result.stderr))

def generate_build_file(gcc_version, include_dirs, arch):
    """Generate BUILD.bazel content for the extracted toolchain.

    Args:
        gcc_version: The GCC version string
        include_dirs: List of include directories
        arch: Target architecture (x86_64 or aarch64)

    Returns:
        String content for BUILD.bazel file
    """
    # Properly format include directories as a Bazel list
    include_dirs_list = []
    for include_dir in include_dirs:
        include_dirs_list.append('"' + include_dir + '"')
    include_dirs_str = "[\n        " + ",\n        ".join(include_dirs_list) + ",\n    ]"

    bazel_cpu = "x86_64" if arch == "x86_64" else "aarch64"

    template = '''load(":cc_toolchain_config.bzl", "cc_toolchain_config")

package(default_visibility = ["//visibility:public"])

# File groups for different tool categories
filegroup(
    name = "all_files",
    srcs = glob(["**/*"]),
)

filegroup(
    name = "compiler_files",
    srcs = [
        "usr/bin/gcc",
        "usr/bin/g++",
        "usr/bin/cpp",
    ] + glob([
        "usr/lib/gcc/**/*",
        "usr/libexec/gcc/**/*",
        "usr/include/**/*",
    ]),
)

filegroup(
    name = "linker_files",
    srcs = [
        "usr/bin/gcc",
        "usr/bin/g++",
        "usr/bin/ld",
        "usr/bin/ld.bfd",
    ] + glob([
        "usr/lib64/**/*.so*",
        "usr/lib64/**/*.a",
        "usr/lib/**/*.so*",
        "usr/lib/**/*.a",
    ]),
)

filegroup(
    name = "ar_files",
    srcs = ["usr/bin/ar"],
)

filegroup(
    name = "objcopy_files",
    srcs = ["usr/bin/objcopy"],
)

filegroup(
    name = "strip_files",
    srcs = ["usr/bin/strip"],
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
    include_dirs = {include_dirs_str},
)

# The actual toolchain
cc_toolchain(
    name = "gcc_toolchain",
    all_files = ":all_files",
    ar_files = ":ar_files",
    compiler_files = ":compiler_files",
    dwp_files = ":empty",
    linker_files = ":linker_files",
    objcopy_files = ":objcopy_files",
    strip_files = ":strip_files",
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
'''

    return template.format(
        gcc_version = gcc_version,
        arch = arch,
        include_dirs_str = include_dirs_str,
        bazel_cpu = bazel_cpu
    )

def generate_cc_toolchain_config(module_name, distro_flags = None):
    """Generate cc_toolchain_config.bzl content with isolated GCC configuration.

    Args:
        module_name: The module name for generating correct external paths
        distro_flags: Dictionary with distribution-specific flags (optional)
                     Expected format: {
                         "c_flags": [...],      # Additional C flags
                         "cxx_flags": [...],    # Additional C++ flags
                         "link_flags": [...]    # Additional linker flags
                     }

    Returns:
        String content for cc_toolchain_config.bzl file with proper header/library isolation
    """
    # Prepare distribution-specific flags
    if not distro_flags:
        distro_flags = {"c_flags": [], "cxx_flags": [], "link_flags": []}

    # Convert flag lists to string format for template
    c_flags_str = ""
    if distro_flags.get("c_flags"):
        quoted_flags = ['"{}"'.format(flag) for flag in distro_flags["c_flags"]]
        c_flags_str = ",\n".join([""] + quoted_flags)

    cxx_flags_str = ""
    if distro_flags.get("cxx_flags"):
        quoted_flags = ['"{}"'.format(flag) for flag in distro_flags["cxx_flags"]]
        cxx_flags_str = ",\n".join([""] + quoted_flags)

    link_flags_str = ""
    if distro_flags.get("link_flags"):
        quoted_flags = ['"{}"'.format(flag) for flag in distro_flags["link_flags"]]
        link_flags_str = ",\n".join([""] + quoted_flags)

    return '''
load("@bazel_tools//tools/cpp:cc_toolchain_config_lib.bzl",
     "feature", "flag_group", "flag_set", "tool_path", "with_feature_set")
load("@bazel_tools//tools/build_defs/cc:action_names.bzl", "ACTION_NAMES")

def _impl(ctx):
    tool_paths = [
        tool_path(name = "gcc", path = "usr/bin/gcc"),
        tool_path(name = "g++", path = "usr/bin/g++"),
        tool_path(name = "ld", path = "usr/bin/ld"),
        tool_path(name = "ar", path = "usr/bin/ar"),
        tool_path(name = "cpp", path = "usr/bin/cpp"),
        tool_path(name = "gcov", path = "usr/bin/gcov"),
        tool_path(name = "nm", path = "usr/bin/nm"),
        tool_path(name = "objdump", path = "usr/bin/objdump"),
        tool_path(name = "strip", path = "usr/bin/strip"),
    ]

    # Compiler flags
    default_compile_flags = feature(
        name = "default_compile_flags",
        enabled = True,
        flag_sets = [
            flag_set(
                actions = [ACTION_NAMES.c_compile],
                flag_groups = [
                    flag_group(
                        flags = [
                            "-B" + "external/{module_name}++{extension_name}+{repo_name}/usr/bin",
                            "-nostdinc",
                            "-isystem", "external/{module_name}++{extension_name}+{repo_name}/usr/lib/gcc/" + ctx.attr.target_arch + "-redhat-linux/" + ctx.attr.gcc_version.split('.')[0] + "/include",
                            "-isystem", "external/{module_name}++{extension_name}+{repo_name}/usr/include",
                            "-Wall",
                            "-Wextra",
                            "-Wno-builtin-macro-redefined",
                            "-D__DATE__=redacted",
                            "-D__TIMESTAMP__=redacted",
                            "-D__TIME__=redacted"{c_flags_str},
                        ],
                    ),
                ],
            ),
            flag_set(
                actions = [ACTION_NAMES.cpp_compile],
                flag_groups = [
                    flag_group(
                        flags = [
                            "-B" + "external/{module_name}++{extension_name}+{repo_name}/usr/bin",
                            "-nostdinc++",
                            "-isystem", "external/{module_name}++{extension_name}+{repo_name}/usr/include/c++/" + ctx.attr.gcc_version.split('.')[0],
                            "-isystem", "external/{module_name}++{extension_name}+{repo_name}/usr/include/c++/" + ctx.attr.gcc_version.split('.')[0] + "/" + ctx.attr.target_arch + "-redhat-linux",
                            "-isystem", "external/{module_name}++{extension_name}+{repo_name}/usr/include/c++/" + ctx.attr.gcc_version.split('.')[0] + "/backward",
                            "-nostdinc",
                            "-isystem", "external/{module_name}++{extension_name}+{repo_name}/usr/lib/gcc/" + ctx.attr.target_arch + "-redhat-linux/" + ctx.attr.gcc_version.split('.')[0] + "/include",
                            "-isystem", "external/{module_name}++{extension_name}+{repo_name}/usr/include",
                            "-Wall",
                            "-Wextra",
                            "-Wno-builtin-macro-redefined",
                            "-D__DATE__=redacted",
                            "-D__TIMESTAMP__=redacted",
                            "-D__TIME__=redacted"{cxx_flags_str},
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
                            "-B" + "external/{module_name}++{extension_name}+{repo_name}/usr/bin",
                            "-L" + "external/{module_name}++{extension_name}+{repo_name}/usr/lib/gcc/" + ctx.attr.target_arch + "-redhat-linux/" + ctx.attr.gcc_version.split('.')[0],
                            "-L" + "external/{module_name}++{extension_name}+{repo_name}/usr/lib64",
                            "-L" + "external/{module_name}++{extension_name}+{repo_name}/usr/lib",
                            "-lstdc++",
                            "-lm"{link_flags_str},
                        ],
                    ),
                ],
            ),
        ],
    )

    # Feature to disable absolute path warnings for system headers
    supports_header_path_normalization = feature(
        name = "supports_header_path_normalization",
        enabled = True,
    )

    return cc_common.create_cc_toolchain_config_info(
        ctx = ctx,
        features = [default_compile_flags, default_link_flags, supports_header_path_normalization],
        cxx_builtin_include_directories = ctx.attr.include_dirs,
        toolchain_identifier = "{distro_name}-gcc-{{}}".format(ctx.attr.gcc_version),
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
        "include_dirs": attr.string_list(),
    }},
    provides = [CcToolchainConfigInfo],
)
'''.format(
        module_name = module_name["module_name"],
        extension_name = module_name["extension_name"],
        repo_name = module_name["repo_name"],
        distro_name = module_name["distro_name"],
        c_flags_str = c_flags_str,
        cxx_flags_str = cxx_flags_str,
        link_flags_str = link_flags_str
    )