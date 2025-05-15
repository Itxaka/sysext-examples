#!/usr/bin/env bash

source ./shared.sh

if [ -n "$MINIUPNPC_VERSION" ];then
  latest_version="$MINIUPNPC_VERSION"
else
  # Try to get the latest version from the REST API
  printf "${GREEN}Checking for latest version from REST API\n"
  api_response=$(curl -s "http://miniupnp.free.fr/files/rest.php/tags/miniupnpc?count=1")

  # Check if the response is valid JSON
  if echo "$api_response" | jq . >/dev/null 2>&1; then
    # Try to extract the version using the correct JSON path
    latest_version=$(echo "$api_response" | jq -r '.tags.miniupnpc[0].version' 2>/dev/null)

    # Debug output
    printf "${GREEN}REST API response: %s\n" "$api_response"
    printf "${GREEN}Extracted version: %s\n" "$latest_version"
  else
    latest_version=""
  fi

  # If REST API fails, try to parse the HTML page
  if [ -z "$latest_version" ] || [ "$latest_version" == "null" ]; then
    printf "${YELLOW}Failed to get latest version from REST API, trying to parse HTML page\n"

    # Try to extract the latest version from the HTML page
    html_page=$(curl -s "http://miniupnp.free.fr/files/")
    if [ -n "$html_page" ]; then
      # Look for miniupnpc-X.X.X.tar.gz pattern and extract the version
      latest_version=$(echo "$html_page" | grep -o 'miniupnpc-[0-9]\+\.[0-9]\+\.[0-9]\+\.tar\.gz' | head -1 | sed 's/miniupnpc-\([0-9]\+\.[0-9]\+\.[0-9]\+\)\.tar\.gz/\1/')
    fi

    # If HTML parsing fails, fall back to a default version
    if [ -z "$latest_version" ]; then
      printf "${YELLOW}Failed to parse HTML page, falling back to default version\n"
      latest_version="2.3.2"
    fi
  fi
fi

printf "${GREEN}Using version %s\n" "$latest_version"

URL=http://miniupnp.free.fr/files/miniupnpc-${latest_version}.tar.gz
SIG_URL=http://miniupnp.free.fr/files/miniupnpc-${latest_version}.tar.gz.sig

FORCE=${FORCE:-false}

if [ -d miniupnpc-"$latest_version" ]; then
  if [ "$FORCE" == "false" ];then
    printf "${RED}Version already exists\n"
    exit 0
  fi
  printf "${YELLOW}Version exists but FORCE was set, removing existing version\n"
  rm -Rf miniupnpc-"$latest_version"
fi

mkdir -p miniupnpc-"$latest_version"
pushd miniupnpc-"$latest_version" > /dev/null || exit 1
createDirs

# Create additional directories
printf "${GREEN}Creating directories\n"
mkdir -p usr/local/bin
mkdir -p usr/local/include/miniupnpc
mkdir -p usr/local/lib
mkdir -p usr/local/share/doc/miniupnpc

# Download MiniUPnPc and signature
printf "${GREEN}Downloading MiniUPnPc and signature\n"
tmpDir=$(mktemp -d)
curl -fsSL "${URL}" -o "$tmpDir/miniupnpc.tar.gz"
curl -fsSL "${SIG_URL}" -o "$tmpDir/miniupnpc.tar.gz.sig" || true

# Verify signature if gpg is available and signature exists
if [ -s "$tmpDir/miniupnpc.tar.gz.sig" ] && command -v gpg &> /dev/null; then
  printf "${GREEN}Verifying signature\n"

  # Try to import MiniUPnP GPG key
  # The key ID is extracted from the signature file
  key_id=$(gpg --verify "$tmpDir/miniupnpc.tar.gz.sig" "$tmpDir/miniupnpc.tar.gz" 2>&1 | grep "using RSA key" | awk '{print $NF}')

  if [ -n "$key_id" ]; then
    printf "${GREEN}Attempting to import key: %s\n" "$key_id"
    gpg --keyserver keyserver.ubuntu.com --recv-keys "$key_id" || \
    gpg --keyserver keys.openpgp.org --recv-keys "$key_id" || \
    gpg --keyserver pgp.mit.edu --recv-keys "$key_id" || true
  else
    printf "${YELLOW}Could not extract key ID from signature\n"
  fi

  # Try to verify again after key import
  if gpg --verify "$tmpDir/miniupnpc.tar.gz.sig" "$tmpDir/miniupnpc.tar.gz"; then
    printf "${GREEN}Signature verification successful\n"
  else
    printf "${RED}Signature verification failed\n"
    # If verification fails but SKIP_VERIFY is set, continue anyway
    if [ "${SKIP_VERIFY:-false}" == "true" ] || [ "${FORCE:-false}" == "true" ]; then
      printf "${YELLOW}SKIP_VERIFY or FORCE is set, continuing despite verification failure\n"
    else
      exit 1
    fi
  fi
elif [ ! -s "$tmpDir/miniupnpc.tar.gz.sig" ]; then
  printf "${YELLOW}Signature file is empty or could not be downloaded, skipping verification\n"
else
  printf "${YELLOW}GPG not available, skipping signature verification\n"
fi

# Extract the tar file
printf "${GREEN}Extracting MiniUPnPc\n"
tar xzf "$tmpDir/miniupnpc.tar.gz" -C "$tmpDir"

# Save the current directory
current_dir=$(pwd)
cd "$tmpDir/miniupnpc-$latest_version" || exit 1

# Build and install
printf "${GREEN}Building MiniUPnPc\n"
make

printf "${GREEN}Installing MiniUPnPc\n"
# Use the built-in installation mechanism with a custom prefix
INSTALLPREFIX="$current_dir/usr/local" make install

# Copy documentation if not already installed
printf "${GREEN}Copying documentation\n"
mkdir -p "$current_dir/usr/local/share/doc/miniupnpc/"
if [ -f "README" ]; then
  cp README "$current_dir/usr/local/share/doc/miniupnpc/"
elif [ -f "README.md" ]; then
  cp README.md "$current_dir/usr/local/share/doc/miniupnpc/"
elif [ -f "README.txt" ]; then
  cp README.txt "$current_dir/usr/local/share/doc/miniupnpc/"
fi

if [ -f "LICENSE" ]; then
  cp LICENSE "$current_dir/usr/local/share/doc/miniupnpc/"
elif [ -f "LICENCE" ]; then
  cp LICENCE "$current_dir/usr/local/share/doc/miniupnpc/"
elif [ -f "COPYING" ]; then
  cp COPYING "$current_dir/usr/local/share/doc/miniupnpc/"
fi

# Return to the original directory
cd "$current_dir" || exit 1

# Clean up
rm -Rf "$tmpDir"

# Create extension release
printf "${GREEN}Creating extension release\n"
createExtensionRelease miniupnpc-"$latest_version" false
find . -type d -empty -delete
popd > /dev/null || exit 1

if [ "${PUSH}" != false ]; then
  buildAndPush miniupnpc-"$latest_version"
fi

if [ "${KEEP_FILES}" == "false" ];then
  rm -Rf miniupnpc-"$latest_version"
fi

printf "${GREEN}Done\n"
