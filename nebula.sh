#!/usr/bin/env bash

source ./shared.sh

# Define service mappings for GitHub Actions workflow
defineServiceMappings "nebula"

if [ -n "$NEBULA_VERSION" ];then
  latest_version="$NEBULA_VERSION"
else
  latest_version=$(curl -s https://api.github.com/repos/slackhq/nebula/releases/latest | jq -r '.tag_name')
fi

printf "${GREEN}Using version %s\n" "$latest_version"

URL=https://github.com/slackhq/nebula/releases/download/${latest_version}/nebula-linux-amd64.tar.gz
SHASUM_URL=https://github.com/slackhq/nebula/releases/download/${latest_version}/SHASUM256.txt

FORCE=${FORCE:-false}

if [ -z "$latest_version" ];then
  exit 1
fi

if [ -d nebula-"$latest_version" ]; then
  if [ "$FORCE" == "false" ];then
    printf "${RED}Version already exists\n"
    exit 0
  fi
  printf "${YELLOW}Version exists but FORCE was set, removing existing version\n"
  rm -Rf ../nebula-"$latest_version"
fi

mkdir -p nebula-"$latest_version"
pushd nebula-"$latest_version" > /dev/null || exit 1
createDirs
# Download Nebula and checksums
printf "${GREEN}Downloading Nebula and checksums\n"
tmpDir=$(mktemp -d)
curl -fsSL "${URL}" -o "$tmpDir/nebula.tar.gz"
curl -fsSL "${SHASUM_URL}" -o "$tmpDir/SHASUM256.txt"

# Verify checksum if sha256sum is available
if command -v sha256sum &> /dev/null; then
  printf "${GREEN}Verifying checksum\n"

  # Extract the checksum for the linux-amd64 tar file
  expected_checksum=$(grep "nebula-linux-amd64.tar.gz$" "$tmpDir/SHASUM256.txt" | awk '{print $1}')

  if [ -n "$expected_checksum" ]; then
    # Calculate the actual checksum
    actual_checksum=$(sha256sum "$tmpDir/nebula.tar.gz" | awk '{print $1}')

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
    printf "${YELLOW}Could not find checksum for nebula-linux-amd64.tar.gz in SHASUM256.txt file\n"
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
printf "${GREEN}Extracting Nebula\n"
tar xzf "$tmpDir/nebula.tar.gz" -C "$tmpDir"

# Move files into proper dirs
printf "${GREEN}Installing Nebula\n"
mv "$tmpDir"/nebula usr/local/sbin
#If you need nebula-cert on your system, move it here too
#mv "$tmpDir"/nebula-cert usr/local/sbin

# Clean up
rm -Rf "$tmpDir"
cp ../services/nebula.* usr/local/lib/systemd/system/
createExtensionRelease nebula-"$latest_version" true
find . -type d -empty -delete
popd > /dev/null || exit 1
if [ "${PUSH}" != false ]; then
  buildAndPush nebula-"$latest_version"
fi
if [ "${KEEP_FILES}" == "false" ];then
  rm -Rf nebula-"$latest_version"
fi
printf "${GREEN}Done\n"
