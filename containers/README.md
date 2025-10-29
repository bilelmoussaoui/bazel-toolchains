# Containers

This directory contains minimal container images for testing the toolchains.

## Building the Containers

```bash
# AutoSD 9 container (minimal, no system GCC)
podman build -t localhost/autosd9 -f Containerfile.autosd9 .

# AutoSD 9 host container (includes system GCC 11.5)
podman build -t localhost/autosd9_host -f Containerfile.autosd9_host .
```

## Running Builds

```bash
# Build with AutoSD 9 isolated toolchain (downloads RPMs)
podman run --rm -v "$(pwd)/..":/workspace:Z -w /workspace localhost/autosd9 \
  bazel build --config=autosd9 //examples/simple_c:hello

# Build with host toolchain (uses system GCC)
podman run --rm -v "$(pwd)/..":/workspace:Z -w /workspace localhost/autosd9_host \
  bazel build --config=host //examples/simple_c:hello
```

## Key Differences

**`autosd9` container:**

- Minimal base with only Bazel
- No system GCC installed
- Tests that toolchain works without any system dependencies

**`autosd9_host` container:**

- Includes system GCC 11.5 from AutoSD 9
- Tests host toolchain detection
