#!/usr/bin/env bash

source ./shared.sh

if [ -n "$PULUMI_ESC_VERSION" ];then
  latest_version="$PULUMI_ESC_VERSION"
else
  latest_version=$(curl -s https://api.github.com/repos/pulumi/esc/releases/latest | jq -r '.tag_name')
fi

printf "${GREEN}Using version %s\n" "$latest_version"

# Remove the 'v' prefix for the file name
version_no_v=${latest_version#v}
URL=https://github.com/pulumi/esc/releases/download/${latest_version}/esc-v${version_no_v}-linux-x64.tar.gz
CHECKSUMS_URL=https://github.com/pulumi/esc/releases/download/${latest_version}/esc-${version_no_v}-checksums.txt

FORCE=${FORCE:-false}

if [ -z "$latest_version" ];then
  exit 1
fi

if [ -d pulumi_esc-"$latest_version" ]; then
  if [ "$FORCE" == "false" ];then
    printf "${RED}Version already exists\n"
    exit 0
  fi
  printf "${YELLOW}Version exists but FORCE was set, removing existing version\n"
  rm -Rf ../pulumi_esc-"$latest_version"
fi

mkdir -p pulumi_esc-"$latest_version"
pushd pulumi_esc-"$latest_version" > /dev/null || exit 1
createDirs
# Download Pulumi ESC and checksums
printf "${GREEN}Downloading Pulumi ESC and checksums\n"
tmpDir=$(mktemp -d)
curl -fsSL "${URL}" -o "$tmpDir/esc.tar.gz"
curl -fsSL "${CHECKSUMS_URL}" -o "$tmpDir/checksums.txt"

# Verify checksum if sha256sum is available
if command -v sha256sum &> /dev/null; then
  printf "${GREEN}Verifying checksum\n"

  # Extract the checksum for the linux-x64 tar file
  expected_checksum=$(grep "esc-v${version_no_v}-linux-x64.tar.gz" "$tmpDir/checksums.txt" | awk '{print $1}')

  if [ -n "$expected_checksum" ]; then
    # Calculate the actual checksum
    actual_checksum=$(sha256sum "$tmpDir/esc.tar.gz" | awk '{print $1}')

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
    printf "${YELLOW}Could not find checksum for esc-v${version_no_v}-linux-x64.tar.gz in checksums.txt file\n"
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
printf "${GREEN}Extracting Pulumi ESC\n"
tar xzf "$tmpDir/esc.tar.gz" --strip-components=1 -C "$tmpDir"

# Move files into proper dirs
printf "${GREEN}Installing Pulumi ESC\n"
mv "$tmpDir"/esc usr/local/sbin

# Clean up
rm -Rf "$tmpDir"
# Copy systemd service files if they exist.
if [ -d ../services ]; then
  if compgen -G "../services/pulumi_esc.*" > /dev/null; then
    cp ../services/pulumi_esc.* usr/local/lib/systemd/system/
  fi
fi
createExtensionRelease pulumi_esc-"$latest_version" true
find . -type d -empty -delete
popd > /dev/null || exit 1
if [ "${PUSH}" != false ]; then
  buildAndPush pulumi_esc-"$latest_version"
fi
if [ "${KEEP_FILES}" == "false" ];then
  rm -Rf pulumi_esc-"$latest_version"
fi
printf "${GREEN}Done\n"
