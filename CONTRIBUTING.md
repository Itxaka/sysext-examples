# Contributing to sysext-examples

This document outlines the process for adding new system extensions to this repository.

## Adding a New System Extension

When adding a new system extension to this repository, follow these steps:

1. **Create the script file**: Create a new script file named after the system extension (e.g., `example.sh`).

2. **Update shared.sh**: Add a new environment variable for the version in `shared.sh`:
   ```bash
   EXAMPLE_VERSION=${EXAMPLE_VERSION:-}
   ```

3. **Create service files**: If the system extension requires systemd service files, create them in the `services/` directory.

4. **Define service mappings**: Add a service mapping to your script using the `defineServiceMappings` function:
   ```bash
   # Define service mappings for GitHub Actions workflow
   defineServiceMappings "service1 service2 service3"
   ```
   This ensures that changes to these service files will trigger a rebuild of your system extension in the GitHub Actions workflow.

5. **Update README.md**: Add the new system extension to the list in the README.md file and include information about the environment variable.

6. **Update GitHub Actions workflow**: Add the new system extension to the `ALL_SYSEXTS` array in `.github/workflows/build.yaml`.

7. **For system extensions with dashes in their names**: If your system extension name contains a dash (e.g., "docker-compose"), add it to the special cases list in the `buildAndPush` function in `shared.sh`.

8. **Document the system extension**: Add a section to the README.md with details about the system extension, including:
   - What it includes
   - Any modifications made from the original source
   - How to build it
   - Any specific configuration options

## Script Structure

The script should follow this general structure:

1. **License and attribution**: Include license information and attribution to original sources.

2. **Version determination**: Determine the version to build, either from the environment variable or by fetching the latest version.

3. **Verification**: Include verification of downloaded artifacts using checksums or GPG signatures.

4. **Directory structure**: Create the appropriate directory structure using the `createDirs` function.

5. **Installation**: Install the binaries and configuration files in the appropriate locations.

6. **Extension release**: Create the extension release file using the `createExtensionRelease` function.

7. **Build and push**: Build and push the Docker image if requested.

## Example

Here's a simplified example of a system extension script:

```bash
#!/usr/bin/env bash
#
# Example system extension script
#
# Based on the example.sysext from example-repo:
# https://github.com/example/example-repo
#
# Original work Copyright 2023 The Example Maintainers
# Licensed under the Apache License, Version 2.0
#

source ./shared.sh

if [ -n "$EXAMPLE_VERSION" ]; then
  latest_version="$EXAMPLE_VERSION"
else
  latest_version=$(curl -s https://api.github.com/repos/example/example/releases/latest | jq -r '.tag_name')
fi

printf "${GREEN}Using version %s\n" "$latest_version"

URL=https://github.com/example/example/releases/download/${latest_version}/example-linux-amd64.tar.gz
SHASUM_URL=https://github.com/example/example/releases/download/${latest_version}/SHASUM256.txt

FORCE=${FORCE:-false}

if [ -z "$latest_version" ]; then
  exit 1
fi

if [ -d example-"$latest_version" ]; then
  if [ "$FORCE" == "false" ]; then
    printf "${RED}Version already exists\n"
    exit 0
  fi
  printf "${YELLOW}Version exists but FORCE was set, removing existing version\n"
  rm -Rf example-"$latest_version"
fi

mkdir -p example-"$latest_version"
pushd example-"$latest_version" > /dev/null || exit 1
createDirs

# Download and verify
# ...

# Install
# ...

# Create service files
# ...

# Clean up
createExtensionRelease example-"$latest_version" true
find . -type d -empty -delete
popd > /dev/null || exit 1
if [ "${PUSH}" != false ]; then
  buildAndPush example-"$latest_version"
fi
if [ "${KEEP_FILES}" == "false" ]; then
  rm -Rf example-"$latest_version"
fi
printf "${GREEN}Done\n"
```

## GitHub Actions Workflow

The GitHub Actions workflow in `.github/workflows/build.yaml` automatically builds and pushes system extensions. The workflow is optimized to only rebuild system extensions that have changed, which improves efficiency.

When adding a new system extension, make sure to:

1. Add it to the `ALL_SYSEXTS` array in the workflow:

```yaml
ALL_SYSEXTS=("k3s" "sbctl" "tailscale" "helm" "k9s" "nebula" "pulumi_esc" "habitat" "incus" "openbao" "alloy" "speedtest" "miniupnpc" "docker" "docker-compose" "falco" "example")
```

2. Define service mappings in your script using the `defineServiceMappings` function:

```bash
# Define service mappings for GitHub Actions workflow
defineServiceMappings "service1 service2 service3"
```

This ensures that changes to these service files will trigger a rebuild of your system extension.

### How the Workflow Works

1. **Detect Changes**: The workflow first detects which files have changed in the commit or PR.
   - If `shared.sh` has changed, all system extensions are rebuilt.
   - Otherwise, only the system extensions with changed script files or service files are rebuilt.
   - The workflow reads service mappings from each script by running it with a special flag, ensuring that changes to service files with different naming conventions are properly detected.

2. **Manual Trigger**: You can manually trigger the workflow for a specific system extension using the workflow_dispatch event.

3. **Scheduled Runs**: The workflow runs on a schedule to rebuild all system extensions, ensuring they stay up-to-date with the latest versions.

This optimized approach ensures that only the necessary system extensions are rebuilt, saving time and resources.
