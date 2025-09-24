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


