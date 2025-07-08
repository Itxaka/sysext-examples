#!/usr/bin/env bash
#
# LibreSpeed CLI system extension script
#
# Based on the LibreSpeed CLI project:
# https://github.com/librespeed/speedtest-cli
#
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
defineServiceMappings ""

if [ -n "$LIBRESPEED_CLI_VERSION" ]; then
  latest_version="$LIBRESPEED_CLI_VERSION"
else
  latest_version=$(curl -s https://api.github.com/repos/librespeed/speedtest-cli/releases/latest | jq -r '.tag_name')
fi

printf "${GREEN}Using version %s\n" "$latest_version"

# Remove the 'v' prefix for the file name
version_no_v=${latest_version#v}

# The github release uses different arch identifiers
rel_arch="amd64"  # Default to amd64
if [ "$(uname -m)" = "aarch64" ]; then
  rel_arch="arm64"
fi

URL=https://github.com/librespeed/speedtest-cli/releases/download/${latest_version}/librespeed-cli_${version_no_v}_linux_${rel_arch}.tar.gz
CHECKSUMS_URL=https://github.com/librespeed/speedtest-cli/releases/download/${latest_version}/checksums.txt

FORCE=${FORCE:-false}

if [ -z "$latest_version" ]; then
  exit 1
fi

if [ -d librespeed-cli-"$latest_version" ]; then
  if [ "$FORCE" == "false" ]; then
    printf "${RED}Version already exists\n"
    exit 0
  fi
  printf "${YELLOW}Version exists but FORCE was set, removing existing version\n"
  rm -Rf librespeed-cli-"$latest_version"
fi

mkdir -p librespeed-cli-"$latest_version"
pushd librespeed-cli-"$latest_version" > /dev/null || exit 1
createDirs

# Download LibreSpeed CLI and checksums
printf "${GREEN}Downloading LibreSpeed CLI and checksums\n"
tmpDir=$(mktemp -d)
curl -fsSL "${URL}" -o "$tmpDir/librespeed-cli.tar.gz"
curl -fsSL "${CHECKSUMS_URL}" -o "$tmpDir/checksums.txt"

# Verify checksum if sha256sum is available
if command -v sha256sum &> /dev/null; then
  printf "${GREEN}Verifying checksum\n"

  # Extract the checksum for the specific architecture tar file
  expected_checksum=$(grep "librespeed-cli_${version_no_v}_linux_${rel_arch}.tar.gz" "$tmpDir/checksums.txt" | awk '{print $1}')

  if [ -n "$expected_checksum" ]; then
    # Calculate the actual checksum
    actual_checksum=$(sha256sum "$tmpDir/librespeed-cli.tar.gz" | awk '{print $1}')

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
    printf "${YELLOW}Could not find checksum for librespeed-cli_${version_no_v}_linux_${rel_arch}.tar.gz in checksums.txt file\n"
    if [ "${SKIP_VERIFY:-false}" == "true" ]; then
      printf "${YELLOW}SKIP_VERIFY is set, continuing without verification\n"
    else
      exit 1
    fi
  fi
else
  printf "${YELLOW}sha256sum not available, skipping checksum verification\n"
fi

# Extract the tar file
printf "${GREEN}Extracting LibreSpeed CLI\n"
tar xzf "$tmpDir/librespeed-cli.tar.gz" -C "$tmpDir"

# Move files into proper dirs
printf "${GREEN}Installing LibreSpeed CLI\n"
mv "$tmpDir/librespeed-cli" usr/local/bin/
chmod +x usr/local/bin/librespeed-cli

# Clean up
rm -Rf "$tmpDir"
createExtensionRelease librespeed-cli-"$latest_version" false
find . -type d -empty -delete
popd > /dev/null || exit 1
if [ "${PUSH}" != false ]; then
  buildAndPush librespeed-cli-"$latest_version"
fi
if [ "${KEEP_FILES}" == "false" ]; then
  rm -Rf librespeed-cli-"$latest_version"
fi
printf "${GREEN}Done\n"
