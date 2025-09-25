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
    for tool in ["rpm2cpio", "cpio", "bash", "grep", "patchelf"]:
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

    # Validate patchelf works
    patchelf_test = repository_ctx.execute(["patchelf", "--version"])
    if patchelf_test.return_code != 0:
        fail("patchelf tool is not working properly. Please ensure patchelf is installed and functional.")

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

    # Patch tools to set RPATH for finding shared libraries
    patch_tool_rpath(repository_ctx)

def patch_tool_rpath(repository_ctx):
    """Patch tools to find their shared libraries using RPATH.

    Args:
        repository_ctx: The repository context provided by Bazel
    """
    # Tools that need patched to find their shared libraries
    tools_to_patch = ["as", "ld"]

    for tool in tools_to_patch:
        original_tool = "usr/bin/{}".format(tool)

        if repository_ctx.path(original_tool).exists:
            print("Patching RPATH for {}".format(tool))

            # Create a separate directory with only the libraries we need (not glibc)
            lib_dir = "usr/lib64/toolchain"
            repository_ctx.execute(["mkdir", "-p", lib_dir])

            # Copy libraries needed by binutils tools (not glibc)
            for lib_pattern in ["libbfd*.so*", "libopcodes*.so*", "libz.so*", "libjansson.so*", "libstdc++.so*", "libgcc_s.so*"]:
                repository_ctx.execute(["bash", "-c", "cp usr/lib64/{} {} 2>/dev/null || true".format(lib_pattern, lib_dir)])

            # Backup the original tool before patching
            backup_tool = original_tool + ".backup"
            repository_ctx.execute(["cp", original_tool, backup_tool])

            # Set RPATH to point to our selective library directory
            result = repository_ctx.execute(["patchelf", "--set-rpath", "$ORIGIN/../lib64/toolchain", original_tool])
            if result.return_code == 0:
                # Verify the tool still works after patching
                test_result = repository_ctx.execute([original_tool, "--version"])
                if test_result.return_code == 0:
                    print("Successfully patched RPATH for {} with selective libraries".format(tool))
                else:
                    print("Warning: {} failed after RPATH patching, restoring backup".format(tool))
                    repository_ctx.execute(["mv", backup_tool, original_tool])
            else:
                print("Warning: Failed to patch RPATH for {}: {}. Restoring backup.".format(tool, result.stderr))
                repository_ctx.execute(["mv", backup_tool, original_tool])



