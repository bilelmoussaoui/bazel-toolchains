#!/usr/bin/env python3
"""
Script to fetch current package versions and SHA256 hashes from Linux distribution repositories.
Supports both Fedora and CentOS. Outputs package information that can be used to update extensions.bzl manually.
"""

import json
import re
import hashlib
import urllib.request
from typing import Dict, Optional
import sys


def get_fedora_package_info(fedora_release: str, arch: str, package_name: str) -> Optional[Dict]:
    """
    Query Fedora repositories for package information using directory listing approach.
    """
    base_url = f"https://download.fedoraproject.org/pub/fedora/linux/releases/{fedora_release}/Everything/{arch}/os/Packages"
    subpath = package_name[0].lower()

    try:
        listing_url = f"{base_url}/{subpath}/"
        request = urllib.request.Request(listing_url)
        request.add_header('User-Agent', 'Multi-GCC-Toolchain-Updater/1.0')

        with urllib.request.urlopen(request) as response:
            html_content = response.read().decode()

        # Parse HTML to find package files
        pattern = rf'{re.escape(package_name)}-([^-]+)-([^-]+)\.fc{fedora_release}\.{arch}\.rpm'
        matches = re.findall(pattern, html_content)

        if matches:
            # Get the latest version (simple sort, may not be perfect)
            version, release = sorted(matches)[-1]
            full_version = f"{version}-{release}.fc{fedora_release}"

            rpm_filename = f"{package_name}-{full_version}.{arch}.rpm"
            download_url = f"{base_url}/{subpath}/{rpm_filename}"

            return {
                'name': package_name,
                'version': full_version,
                'subpath': subpath,
                'url': download_url,
                'filename': rpm_filename
            }

    except Exception as e:
        print(f"Error querying Fedora repository for {package_name}: {e}")

    return None


def get_centos_package_info(centos_release: str, arch: str, package_name: str) -> Optional[Dict]:
    """
    Query CentOS repositories for package information using directory listing approach.
    """
    base_url = f"https://mirror.stream.centos.org/{centos_release}-stream/AppStream/{arch}/os/Packages"

    try:
        # CentOS packages are directly in the Packages directory, no subpath
        listing_url = f"{base_url}/"
        request = urllib.request.Request(listing_url)
        request.add_header('User-Agent', 'Multi-GCC-Toolchain-Updater/1.0')

        with urllib.request.urlopen(request) as response:
            html_content = response.read().decode()

        # Parse HTML to find package files
        # CentOS uses .el9 instead of .fc42
        pattern = rf'{re.escape(package_name)}-([^-]+)-([^-]+)\.el{centos_release}\.{arch}\.rpm'
        matches = re.findall(pattern, html_content)

        if matches:
            # Get the latest version (simple sort, may not be perfect)
            version, release = sorted(matches)[-1]
            full_version = f"{version}-{release}.el{centos_release}"

            rpm_filename = f"{package_name}-{full_version}.{arch}.rpm"
            download_url = f"{base_url}/{rpm_filename}"

            return {
                'name': package_name,
                'version': full_version,
                'subpath': "",  # No subpath for CentOS
                'url': download_url,
                'filename': rpm_filename
            }

    except Exception as e:
        print(f"Error querying CentOS repository for {package_name}: {e}")

    return None


def get_sha256_from_url(url: str) -> Optional[str]:
    """
    Download a file and compute its SHA256 hash.
    """
    print(f"Computing SHA256 for {url}")

    try:
        request = urllib.request.Request(url)
        request.add_header('User-Agent', 'Multi-GCC-Toolchain-Updater/1.0')

        with urllib.request.urlopen(request) as response:
            sha256_hash = hashlib.sha256()

            # Read in chunks to handle large files
            while chunk := response.read(8192):
                sha256_hash.update(chunk)

        return sha256_hash.hexdigest()

    except Exception as e:
        print(f"Error computing SHA256 for {url}: {e}")
        return None


def output_package_info(packages_info: Dict[str, Dict], arch: str, distro: str) -> None:
    """
    Output the package information in a format that can be copied to extensions.bzl
    """
    print("\n" + "="*60)
    print(f"PACKAGE INFORMATION FOR {distro.upper()} extensions.bzl ({arch})")
    print("="*60)

    print(f'        "{arch}": {{')
    for pkg_name, info in packages_info.items():
        print(f'            "{pkg_name}": {{')
        print(f'                "version": "{info["version"]}",')
        print(f'                "sha256": "{info["sha256"]}",')
        print(f'                "subpath": "{info["subpath"]}"')
        print(f'            }},')
    print('        },')

    print("\n" + "="*60)
    print(f"Copy the above {arch} section into the _PACKAGES_BY_ARCH dictionary in {distro}_gcc/extensions.bzl")
    print("="*60)


def main():
    if len(sys.argv) != 4:
        print("Usage: python3 update_packages.py <distro> <release> <arch>")
        print("  distro: Distribution name (fedora or centos)")
        print("  release: Distribution version (e.g., 42 for Fedora, 9 for CentOS)")
        print("  arch: Target architecture (x86_64 or aarch64)")
        print("Examples:")
        print("  python3 update_packages.py fedora 42 x86_64")
        print("  python3 update_packages.py centos 9 x86_64")
        sys.exit(1)

    distro = sys.argv[1].lower()
    release = sys.argv[2]
    arch = sys.argv[3]

    # Validate distribution
    supported_distros = ['fedora', 'centos']
    if distro not in supported_distros:
        print(f"Error: Unsupported distribution '{distro}'. Supported: {supported_distros}")
        sys.exit(1)

    # Validate architecture
    supported_arches = ['x86_64', 'aarch64']
    if arch not in supported_arches:
        print(f"Error: Unsupported architecture '{arch}'. Supported: {supported_arches}")
        sys.exit(1)

    # Validate release format (should be a number)
    if not release.isdigit():
        print(f"Error: Release should be a number (e.g., '42' for Fedora, '9' for CentOS), got: '{release}'")
        sys.exit(1)

    # Essential packages we need (same for both distributions)
    package_names = [
        'gcc',
        'gcc-c++',
        'cpp',
        'binutils',
        'glibc-devel',
        'libstdc++-devel',
        'libstdc++'
    ]

    packages_info = {}

    print(f"Fetching package information for {distro.capitalize()} {release} ({arch})...")

    # Choose the appropriate function based on distribution
    if distro == 'fedora':
        get_package_info = get_fedora_package_info
    elif distro == 'centos':
        get_package_info = get_centos_package_info
    else:
        print(f"Error: Unknown distribution: {distro}")
        sys.exit(1)

    for package_name in package_names:
        print(f"Processing {package_name}...")

        # Get package info using the appropriate function
        info = get_package_info(release, arch, package_name)

        if info:
            # Get SHA256 hash
            sha256 = get_sha256_from_url(info['url'])
            if sha256:
                info['sha256'] = sha256
                packages_info[package_name] = info
                print(f"  ✓ {package_name}: {info['version']} (SHA256: {sha256[:16]}...)")
            else:
                print(f"  ✗ Failed to get SHA256 for {package_name}")
        else:
            print(f"  ✗ Failed to get info for {package_name}")

    if packages_info:
        print(f"\nSuccessfully processed {len(packages_info)} packages")
        output_package_info(packages_info, arch, distro)
        print("Done!")
    else:
        print("No packages were successfully processed")
        sys.exit(1)


if __name__ == '__main__':
    main()