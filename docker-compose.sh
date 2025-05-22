#!/usr/bin/env bash
#
# Docker Compose system extension script
#
# Based on the docker-compose.sysext from sysext-bakery:
# https://github.com/flatcar/sysext-bakery/tree/main/docker-compose.sysext
#
# Original work Copyright 2023 The Flatcar Maintainers
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

source ./shared.sh

# Define service mappings for GitHub Actions workflow
defineServiceMappings "docker-compose"

if [ -n "$DOCKER_COMPOSE_VERSION" ]; then
  latest_version="$DOCKER_COMPOSE_VERSION"
else
  latest_version=$(curl -s https://api.github.com/repos/docker/compose/releases/latest | jq -r '.tag_name' | sed 's/^v//')
fi

printf "${GREEN}Using version %s\n" "$latest_version"

# The github release uses different arch identifiers
rel_arch="x86_64"  # Default to x86_64
if [ "$(uname -m)" = "aarch64" ]; then
  rel_arch="aarch64"
fi

URL=https://github.com/docker/compose/releases/download/v${latest_version}/docker-compose-linux-${rel_arch}
SHASUM_URL=https://github.com/docker/compose/releases/download/v${latest_version}/docker-compose-linux-${rel_arch}.sha256

FORCE=${FORCE:-false}

if [ -z "$latest_version" ]; then
  exit 1
fi

if [ -d docker-compose-"$latest_version" ]; then
  if [ "$FORCE" == "false" ]; then
    printf "${RED}Version already exists\n"
    exit 0
  fi
  printf "${YELLOW}Version exists but FORCE was set, removing existing version\n"
  rm -Rf docker-compose-"$latest_version"
fi

mkdir -p docker-compose-"$latest_version"
pushd docker-compose-"$latest_version" > /dev/null || exit 1
createDirs

# Create directories for docker-compose
mkdir -p usr/local/lib/docker/cli-plugins

# Download Docker Compose and checksums
printf "${GREEN}Downloading Docker Compose and checksums\n"
tmpDir=$(mktemp -d)
curl -fsSL "${URL}" -o "$tmpDir/docker-compose"
curl -fsSL "${SHASUM_URL}" -o "$tmpDir/docker-compose.sha256"

# Verify checksum if sha256sum is available
if command -v sha256sum &> /dev/null; then
  printf "${GREEN}Verifying checksum\n"

  # Extract the expected checksum
  expected_checksum=$(cat "$tmpDir/docker-compose.sha256" | awk '{print $1}')

  if [ -n "$expected_checksum" ]; then
    # Calculate the actual checksum
    actual_checksum=$(sha256sum "$tmpDir/docker-compose" | awk '{print $1}')

    if [ "$actual_checksum" = "$expected_checksum" ]; then
      printf "${GREEN}Checksum verification successful\n"
    else
      printf "${RED}Checksum verification failed\n"
      printf "${RED}Expected: %s\n" "$expected_checksum"
      printf "${RED}Actual: %s\n" "$actual_checksum"
      # If verification fails but SKIP_VERIFY is set, continue anyway
      if [ "${SKIP_VERIFY:-false}" == "true" ]; then
        printf "${YELLOW}SKIP_VERIFY is set, continuing despite verification failure\n"
      else
        exit 1
      fi
    fi
  else
    printf "${YELLOW}Could not extract checksum from sha256sum file\n"
    if [ "${SKIP_VERIFY:-false}" == "true" ]; then
      printf "${YELLOW}SKIP_VERIFY is set, continuing without verification\n"
    else
      exit 1
    fi
  fi
else
  printf "${YELLOW}sha256sum not available, skipping checksum verification\n"
fi

# Move files into proper dirs
printf "${GREEN}Installing Docker Compose\n"
cp "$tmpDir/docker-compose" usr/local/lib/docker/cli-plugins/
chmod +x usr/local/lib/docker/cli-plugins/docker-compose

# Create a symlink in usr/local/bin for backward compatibility
mkdir -p usr/local/bin
ln -sf ../lib/docker/cli-plugins/docker-compose usr/local/bin/docker-compose

# Clean up
rm -Rf "$tmpDir"
createExtensionRelease docker-compose-"$latest_version" false
find . -type d -empty -delete
popd > /dev/null || exit 1
if [ "${PUSH}" != false ]; then
  buildAndPush docker-compose-"$latest_version"
fi
if [ "${KEEP_FILES}" == "false" ]; then
  rm -Rf docker-compose-"$latest_version"
fi
printf "${GREEN}Done\n"
