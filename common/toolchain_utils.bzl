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

    # Validate rpm2cpio specifically works (try multiple approaches since different versions behave differently)
    rpm2cpio_test = repository_ctx.execute(["rpm2cpio", "--help"])
    if rpm2cpio_test.return_code != 0:
        # Some versions don't support --help, try with no args (should show usage and exit with code 1)
        rpm2cpio_test2 = repository_ctx.execute(["rpm2cpio"])
        if rpm2cpio_test2.return_code not in [0, 1, 2]:
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

def detect_gcc_version(repository_ctx, gcc_path = "./usr/bin/gcc"):
    """Detect GCC version from a GCC binary.

    Args:
        repository_ctx: The repository context provided by Bazel
        gcc_path: Path to the GCC binary (defaults to extracted RPM path)

    Returns:
        Tuple: (gcc_version, gcc_major) where gcc_version is full version and gcc_major is major version
    """
    # Detect GCC version from the specified GCC binary
    gcc_version_result = repository_ctx.execute([
        "bash", "-c",
        "{} --version | head -1 | grep -o '[0-9]\\+\\.[0-9]\\+\\.[0-9]\\+' | head -1".format(gcc_path)
    ])

    if gcc_version_result.return_code == 0 and gcc_version_result.stdout.strip():
        gcc_version = gcc_version_result.stdout.strip()
        # Remove any extra whitespace or newlines
        gcc_version = gcc_version.replace('\n', '').replace('\r', '').strip()
        if not gcc_version:
            fail("Failed to detect GCC version: empty version string")
    else:
        context = "host system" if gcc_path == "gcc" else "extracted toolchain"
        fail("Failed to detect GCC version from {}. Command failed with: {}".format(
            context, gcc_version_result.stderr if gcc_version_result.stderr else "No error output"
        ))

    gcc_major = gcc_version.split('.')[0]
    context_msg = "host" if gcc_path == "gcc" else "extracted"
    print("Detected {} GCC version: {}".format(context_msg, gcc_version))

    return gcc_version, gcc_major


def download_and_extract_packages(repository_ctx, packages, base_url_template, release, rpm_arch, repo_name):
    """Download RPM packages and set up an isolated toolchain environment.

    Downloads and extracts RPMs, then creates wrappers and symlinks for proper isolation:
    - Toolchain runtime libraries accessible via LD_LIBRARY_PATH
    - Sysroot structure for --sysroot flag compatibility
    - Binary wrappers to find dependencies

    Args:
        repository_ctx: The repository context provided by Bazel
        packages: Dictionary of package info with version, subpath, sha256
        base_url_template: URL template for downloads (with placeholders)
        release: Distribution release version (e.g., "42")
        rpm_arch: Target architecture (e.g., "x86_64")
        repo_name: Repository name for error messages and logging
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
            package_dir = info.get("package_dir", "AppStream"), # in the format of Appstream / or BaseOS for Centos
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

    # Create toolchain library directory
    # Toolchain binaries need specific library versions (libbfd, libopcodes, etc.)
    # that may not exist on the host. Symlink them to a controlled directory.
    repository_ctx.execute(["mkdir", "-p", "usr/lib64/toolchain"])

    # Symlink only the essential libraries needed by toolchain binaries themselves
    # (not libraries for compiling user code - those go in the sysroot)
    toolchain_libs = ["libbfd*.so*", "libopcodes*.so*", "libctf*.so*", "libmpc.so*", "libgmp.so*", "libmpfr.so*"]
    for lib_pattern in toolchain_libs:
        repository_ctx.execute([
            "bash", "-c",
            "for lib in usr/lib64/{}; do [ -f \"$lib\" ] && ln -sf \"../$(basename \"$lib\")\" usr/lib64/toolchain/; done".format(lib_pattern)
        ])

    # Create sysroot structure
    # GCC expects libraries in /lib64 and /lib with --sysroot, but RPMs place them
    # in /usr/lib64 and /usr/lib. Create symlinks for compatibility.

    # Create symlinks for all files in usr/lib64 -> lib64
    lib64_result = repository_ctx.execute(["find", "usr/lib64", "-type", "f"])
    if lib64_result.return_code == 0:
        for file_path in lib64_result.stdout.strip().split('\n'):
            if file_path:  # Skip empty lines
                filename = file_path.split('/')[-1]  # Get just the filename
                target_path = "lib64/{}".format(filename)
                if not repository_ctx.path(target_path).exists:
                    repository_ctx.symlink(file_path, target_path)

    # Create symlinks for all files in usr/lib -> lib
    lib_result = repository_ctx.execute(["find", "usr/lib", "-type", "f"])
    if lib_result.return_code == 0:
        for file_path in lib_result.stdout.strip().split('\n'):
            if file_path:  # Skip empty lines
                filename = file_path.split('/')[-1]  # Get just the filename
                target_path = "lib/{}".format(filename)
                if not repository_ctx.path(target_path).exists:
                    repository_ctx.symlink(file_path, target_path)


    # Wrap toolchain binaries
    # Set LD_LIBRARY_PATH so binaries find their libraries without host conflicts.

    tools = ["gcc", "g++", "cpp", "ar", "ld", "ld.bfd", "objcopy", "strip", "objdump", "as", "nm", "gcov"]

    for tool in tools:
        tool_path = "usr/bin/{}".format(tool)
        wrapper_path = "usr/bin/{}_wrapper".format(tool)

        # Check if the tool exists before creating a wrapper (some tools may not be in all packages)
        if repository_ctx.path(tool_path).exists:
            wrapper_content = """#!/bin/sh
# Wrapper for {} to set library path for extracted toolchain
SCRIPT_DIR="$(dirname "$(readlink -f "$0")")"
REPO_ROOT="$(dirname "$(dirname "$SCRIPT_DIR")")"
# Only add specific toolchain libraries, not the entire lib directory
# Use env to set LD_LIBRARY_PATH only for the exec'd command, not for the shell itself
exec env LD_LIBRARY_PATH="$REPO_ROOT/usr/lib64/toolchain:$LD_LIBRARY_PATH" "$REPO_ROOT/usr/bin/{}_original" "$@"
""".format(tool, tool)

            repository_ctx.file(wrapper_path, wrapper_content, executable=True)

            # Replace the original tool with the wrapper
            repository_ctx.execute(["mv", tool_path, "{}_original".format(tool_path)])
            repository_ctx.execute(["mv", wrapper_path, tool_path])



