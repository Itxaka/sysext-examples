#!/usr/bin/env bash

source ./shared.sh

# Define service mappings for GitHub Actions workflow
defineServiceMappings "tailscaled"

if [ -n "$TAILSCALE_VERSION" ];then
  # If a specific version is provided, use it
  latest_version="$TAILSCALE_VERSION"
  clean_version="${latest_version#v}"
  URL=https://pkgs.tailscale.com/stable/tailscale_${clean_version}_amd64.tgz
  printf "${GREEN}Using specified version %s\n" "$latest_version"
  printf "${GREEN}Download URL: %s\n" "$URL"
else
  # Fetch the latest available version from the static binaries page
  printf "${GREEN}Fetching latest available Tailscale static binary...\n"

  # Get the static binaries page and extract the amd64 download link
  static_page=$(curl -s https://pkgs.tailscale.com/stable/#static)

  # Extract the amd64 link - look for pattern like "tailscale_X.Y.Z_amd64.tgz"
  amd64_filename=$(echo "$static_page" | grep -o 'tailscale_[0-9]\+\.[0-9]\+\.[0-9]\+_amd64\.tgz' | head -1)

  if [ -z "$amd64_filename" ]; then
    printf "${YELLOW}Could not find amd64 static binary link, using fallback\n"
    amd64_filename="tailscale_1.84.0_amd64.tgz"
  fi

  # Extract version from filename
  clean_version=$(echo "$amd64_filename" | sed 's/tailscale_\([0-9]\+\.[0-9]\+\.[0-9]\+\)_amd64\.tgz/\1/')
  latest_version="v${clean_version}"

  URL="https://pkgs.tailscale.com/stable/${amd64_filename}"

  printf "${GREEN}Found latest available static binary version: %s\n" "$latest_version"
  printf "${GREEN}Download URL: %s\n" "$URL"
fi

# Validate that we have a proper version
if [ -z "$latest_version" ] || [ -z "$clean_version" ]; then
  printf "${RED}Failed to determine Tailscale version\n"
  exit 1
fi

FORCE=${FORCE:-false}

if [ -z "$latest_version" ];then
  exit 1
fi

if [ -d tailscale-"$latest_version" ]; then
  if [ "$FORCE" == "false" ];then
    printf "${RED}Version already exists\n"
    exit 0
  fi
  printf "${YELLOW}Version exists but FORCE was set, removing existing version\n"
  rm -Rf ../tailscale-"$latest_version"
fi

mkdir -p tailscale-"$latest_version"
pushd tailscale-"$latest_version" > /dev/null || exit 1
createDirs
# Download and extract Tailscale
tmpDir=$(mktemp -d)

printf "${GREEN}Downloading Tailscale from: %s\n" "$URL"

# Try to download the requested version
if curl -fsSL "${URL}" -o "$tmpDir/tailscale.tgz"; then
  printf "${GREEN}Successfully downloaded version %s\n" "$clean_version"
else
  printf "${YELLOW}Failed to download version %s, trying fallback version 1.84.0\n" "$clean_version"

  # Try fallback version 1.84.0
  fallback_version="1.84.0"
  fallback_url="https://pkgs.tailscale.com/stable/tailscale_${fallback_version}_amd64.tgz"

  printf "${GREEN}Trying fallback URL: %s\n" "$fallback_url"

  if curl -fsSL "${fallback_url}" -o "$tmpDir/tailscale.tgz"; then
    printf "${GREEN}Successfully downloaded fallback version %s\n" "$fallback_version"
    clean_version="$fallback_version"
    latest_version="v$fallback_version"
  else
    printf "${RED}Failed to download both requested and fallback versions\n"
    rm -rf "$tmpDir"
    exit 1
  fi
fi

# Extract the downloaded file
printf "${GREEN}Extracting Tailscale archive\n"
if ! tar xzf "$tmpDir/tailscale.tgz" --strip-components=1 -C "$tmpDir"; then
  printf "${RED}Failed to extract Tailscale archive\n"
  rm -rf "$tmpDir"
  exit 1
fi
# move files into proper dirs
mv "$tmpDir"/tailscale usr/local/sbin
mv "$tmpDir"/tailscaled usr/local/sbin
rm -Rf "$tmpDir"
cp ../services/tailscaled.* usr/local/lib/systemd/system/
createExtensionRelease tailscale-"$latest_version" true
find . -type d -empty -delete
popd > /dev/null || exit 1
if [ "${PUSH}" != false ]; then
  buildAndPush tailscale-"$latest_version"
fi
if [ "${KEEP_FILES}" == "false" ];then
  rm -Rf tailscale-"$latest_version"
fi
printf "${GREEN}Done\n"
