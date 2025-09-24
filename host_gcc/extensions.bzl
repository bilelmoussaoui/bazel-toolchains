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

    # Use BUILD template instead of generating dynamically
    bazel_cpu = "x86_64" if rpm_arch == "x86_64" else "aarch64"

    # Format flag lists for template substitution
    c_flags_str = ', '.join(['"{}"'.format(flag) for flag in host_flags.get("c_flags", [])])
    cxx_flags_str = ', '.join(['"{}"'.format(flag) for flag in host_flags.get("cxx_flags", [])])
    link_flags_str = ', '.join(['"{}"'.format(flag) for flag in host_flags.get("link_flags", [])])
    include_dirs_str = ', '.join(['"{}"'.format(inc_dir) for inc_dir in system_includes])

    repository_ctx.template(
        "BUILD.bazel",
        Label("@multi_gcc_toolchain//host_gcc:BUILD.bazel.template"),
        substitutions = {
            "{GCC_VERSION}": gcc_version,
            "{TARGET_ARCH}": rpm_arch,
            "{BAZEL_CPU}": bazel_cpu,
            "{C_FLAGS}": c_flags_str,
            "{CXX_FLAGS}": cxx_flags_str,
            "{LINK_FLAGS}": link_flags_str,
            "{INCLUDE_DIRS}": include_dirs_str,
        },
    )

    # Copy static template instead of generating dynamically
    repository_ctx.template(
        "cc_toolchain_config.bzl",
        Label("@multi_gcc_toolchain//host_gcc:cc_toolchain_config.bzl.template"),
        substitutions = {},  # No substitutions needed - everything is handled via rule attributes
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