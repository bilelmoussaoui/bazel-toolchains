#!/usr/bin/env python3
"""
Script to fetch current package versions and SHA256 hashes from Linux distribution repositories.
Supports Fedora and AutoSD (CentOS Stream). Automatically fetches all supported distributions
and architectures, then outputs a comprehensive JSON file.
"""

from bs4 import BeautifulSoup
import re
import hashlib
import urllib.request
from typing import Dict, Optional
import json


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
    Query AutoSD repositories for package information using directory listing approach.
    AutoSD packages are in the AutoSD compose repository.
    """
    # Use different URLs for listing and downloading
    listing_base_url = f"https://autosd.sig.centos.org/AutoSD-{centos_release}/nightly/repos/AutoSD/compose/AutoSD/{arch}/os/Packages"
    download_base_url = f"https://download.autosd.sig.centos.org/AutoSD-{centos_release}/nightly/repos/AutoSD/compose/AutoSD/{arch}/os/Packages"

    try:
        # Use listing URL to get package information
        listing_url = f"{listing_base_url}/"
        request = urllib.request.Request(listing_url)
        request.add_header('User-Agent', 'Multi-GCC-Toolchain-Updater/1.0')

        with urllib.request.urlopen(request) as response:
            html_content = response.read().decode()

        # Parse HTML to find package files
        soup = BeautifulSoup(html_content, 'html.parser')

        links = soup.select('pre a')
        # Loop through all the found links
        for link in links:
            filename = link.text
            # Use a simple regex to check if the filename ends with '.rpm'
            if filename.endswith(".rpm"):
                pattern = rf'^{re.escape(package_name)}-(.*)-([^\-]+)\.el{centos_release}\.{arch}\.rpm$'
                matches = re.findall(pattern, filename)

                if matches:
                    # Get the latest version (simple sort, may not be perfect)
                    version, release = sorted(matches)[-1]
                    full_version = f"{version}-{release}.el{centos_release}"

                    rpm_filename = f"{package_name}-{full_version}.{arch}.rpm"
                    # Use download URL for actual package download
                    download_url = f"{download_base_url}/{rpm_filename}"

                    return {
                        'name': package_name,
                        'version': full_version,
                        'url': download_url,
                        'filename': rpm_filename
                    }

    except Exception as e:
        print(f"Error querying AutoSD repository for {package_name}: {e}")

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


def main():
    # Essential packages we need (base list for all distributions)
    base_package_names = [
        'gcc',
        'gcc-c++',
        'cpp',
        'binutils',
        'glibc-devel',
        'libstdc++-devel',
        'libstdc++',
        'kernel-headers',
        'glibc',
        'libgcc',
        'libmpc',
        'gmp',
        'mpfr',
    ]

    # Configuration for all supported distributions and architectures
    configs = [
        {'distro': 'fedora', 'release': '42', 'arches': ['x86_64', 'aarch64'], 'packages': base_package_names},
        {'distro': 'centos', 'release': '10', 'arches': ['x86_64', 'aarch64'], 'name': 'autosd_10', 'packages': base_package_names},
        {'distro': 'centos', 'release': '9', 'arches': ['x86_64', 'aarch64'], 'name': 'autosd_9', 'packages': base_package_names + ['glibc-headers']},
    ]

    all_results = {}

    for config in configs:
        distro = config['distro']
        release = config['release']
        distro_name = config.get('name', distro)
        package_names = config['packages']

        all_results[distro_name] = {}

        # Choose the appropriate function based on distribution
        if distro == 'fedora':
            get_package_info = get_fedora_package_info
        elif distro == 'centos':
            get_package_info = get_centos_package_info
        else:
            print(f"Error: Unknown distribution: {distro}")
            continue

        for arch in config['arches']:
            print(f"\n{'='*80}")
            print(f"Fetching {distro_name} {release} ({arch})...")
            print(f"{'='*80}")

            packages_info = {}

            for package_name in package_names:
                print(f"Processing {package_name}...")

                # Get package info using the appropriate function
                info = get_package_info(release, arch, package_name)

                if info:
                    # Get SHA256 hash
                    sha256 = get_sha256_from_url(info['url'])
                    if sha256:
                        packages_info[package_name] = {
                            'version': info['version'],
                            'sha256': sha256,
                        }
                        if distro == 'fedora':
                            packages_info[package_name]['subpath'] = info['subpath']

                        print(f"  ✓ {package_name}: {info['version']} (SHA256: {sha256[:16]}...)")
                    else:
                        print(f"  ✗ Failed to get SHA256 for {package_name}")
                else:
                    print(f"  ✗ Failed to get info for {package_name}")

            if packages_info:
                all_results[distro_name][arch] = packages_info
                print(f"\n✓ Successfully processed {len(packages_info)} packages for {distro_name} {arch}")
            else:
                print(f"\n✗ No packages were successfully processed for {distro_name} {arch}")

    # Write JSON output
    output_file = 'package_versions.json'
    with open(output_file, 'w') as f:
        json.dump(all_results, f, indent=2)

    print(f"\n{'='*80}")
    print(f"✓ All package information written to {output_file}")
    print(f"{'='*80}")

    # Print summary
    print("\nSummary:")
    for distro_name, arches in all_results.items():
        for arch, packages in arches.items():
            print(f"  {distro_name} {arch}: {len(packages)} packages")

    print(f"\nJSON output saved to: {output_file}")
    print("You can now use this file to update the extensions.bzl files.")


if __name__ == '__main__':
    main()
