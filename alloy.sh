#!/usr/bin/env bash

source ./shared.sh

# Define service mappings for GitHub Actions workflow
defineServiceMappings "alloy"

if [ -n "$ALLOY_VERSION" ];then
  latest_version="$ALLOY_VERSION"
else
  latest_version=$(curl -s https://api.github.com/repos/grafana/alloy/releases/latest | jq -r '.tag_name')
fi

printf "${GREEN}Using version %s\n" "$latest_version"

# Remove the 'v' prefix for the file name
version_no_v=${latest_version#v}
URL=https://github.com/grafana/alloy/releases/download/${latest_version}/alloy-linux-amd64.zip
SUMS_URL=https://github.com/grafana/alloy/releases/download/${latest_version}/SHA256SUMS

FORCE=${FORCE:-false}

if [ -z "$latest_version" ];then
  exit 1
fi

if [ -d alloy-"$latest_version" ]; then
  if [ "$FORCE" == "false" ];then
    printf "${RED}Version already exists\n"
    exit 0
  fi
  printf "${YELLOW}Version exists but FORCE was set, removing existing version\n"
  rm -Rf alloy-"$latest_version"
fi

mkdir -p alloy-"$latest_version"
pushd alloy-"$latest_version" > /dev/null || exit 1
createDirs

# Download Alloy and checksums
printf "${GREEN}Downloading Alloy and checksums\n"
tmpDir=$(mktemp -d)
curl -fsSL "${URL}" -o "$tmpDir/alloy.zip"
curl -fsSL "${SUMS_URL}" -o "$tmpDir/SHA256SUMS"

# Verify checksum if sha256sum is available
if command -v sha256sum &> /dev/null; then
  printf "${GREEN}Verifying checksum\n"

  # Extract the checksum for the linux-amd64 zip file
  expected_checksum=$(grep "alloy-linux-amd64.zip" "$tmpDir/SHA256SUMS" | awk '{print $1}')

  if [ -n "$expected_checksum" ]; then
    # Calculate the actual checksum
    actual_checksum=$(sha256sum "$tmpDir/alloy.zip" | awk '{print $1}')

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
    printf "${YELLOW}Could not find checksum for alloy-linux-amd64.zip in SHA256SUMS file\n"
    if [ "${SKIP_VERIFY:-false}" == "true" ]; then
      printf "${YELLOW}SKIP_VERIFY is set, continuing without verification\n"
    else
      exit 1
    fi
  fi
else
  printf "${YELLOW}sha256sum not available, skipping checksum verification\n"
fi

# Extract the zip file
printf "${GREEN}Extracting Alloy binary\n"
unzip -q "$tmpDir/alloy.zip" -d "$tmpDir"

# Move files into proper dirs
mv "$tmpDir/alloy-linux-amd64" usr/local/bin/alloy
chmod +x usr/local/bin/alloy

# Clean up
rm -Rf "$tmpDir"

# Copy service files
printf "${GREEN}Copying service files\n"
cp ../services/alloy.* usr/local/lib/systemd/system/

# Create extension release
printf "${GREEN}Creating extension release\n"
createExtensionRelease alloy-"$latest_version" true
find . -type d -empty -delete
popd > /dev/null || exit 1

if [ "${PUSH}" != false ]; then
  buildAndPush alloy-"$latest_version"
fi

if [ "${KEEP_FILES}" == "false" ];then
  rm -Rf alloy-"$latest_version"
fi

printf "${GREEN}Done\n"
