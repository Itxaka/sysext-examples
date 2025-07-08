#!/usr/bin/env bash

source ./shared.sh

# Define service mappings for GitHub Actions workflow
defineServiceMappings "openbao"

if [ -n "$OPENBAO_VERSION" ];then
  latest_version="$OPENBAO_VERSION"
else
  latest_version=$(curl -s https://api.github.com/repos/openbao/openbao/releases/latest | jq -r '.tag_name')
fi

printf "${GREEN}Using version %s\n" "$latest_version"

# Remove the 'v' prefix for the file name
version_no_v=${latest_version#v}
URL=https://github.com/openbao/openbao/releases/download/${latest_version}/bao_${version_no_v}_Linux_x86_64.tar.gz
SIG_URL=https://github.com/openbao/openbao/releases/download/${latest_version}/bao_${version_no_v}_Linux_x86_64.tar.gz.gpgsig

FORCE=${FORCE:-false}

if [ -z "$latest_version" ];then
  exit 1
fi

if [ -d openbao-"$latest_version" ]; then
  if [ "$FORCE" == "false" ];then
    printf "${RED}Version already exists\n"
    exit 0
  fi
  printf "${YELLOW}Version exists but FORCE was set, removing existing version\n"
  rm -Rf ../openbao-"$latest_version"
fi

mkdir -p openbao-"$latest_version"
pushd openbao-"$latest_version" > /dev/null || exit 1
createDirs

# Download OpenBao and signature
printf "${GREEN}Downloading OpenBao and signature\n"
tmpDir=$(mktemp -d)
curl -fsSL "${URL}" -o "$tmpDir/openbao.tar.gz"
curl -fsSL "${SIG_URL}" -o "$tmpDir/openbao.tar.gz.gpgsig"

# Check if the signature file is empty or invalid
if [ ! -s "$tmpDir/openbao.tar.gz.gpgsig" ]; then
  printf "${YELLOW}Signature file is empty or could not be downloaded\n"
  if [ "${SKIP_VERIFY:-false}" == "true" ]; then
    printf "${YELLOW}SKIP_VERIFY is set, continuing without verification\n"
  else
    printf "${RED}Signature verification failed - empty signature file\n"
    exit 1
  fi
fi

# Verify signature if gpg is available and we have a valid signature file
if [ -s "$tmpDir/openbao.tar.gz.gpgsig" ] && command -v gpg &> /dev/null; then
  printf "${GREEN}Verifying signature\n"

  # Download and import the OpenBao GPG key
  # Primary key fingerprint: 66D1 5FDD 8728 7219 C8E1 5478 D200 CD70 2853 E6D0
  # Subkey fingerprint: E617 DCD4 065C 2AFC 0B2C F7A7 BA8B C08C 0F69 1F94
  curl -fsSL "https://openbao.org/assets/openbao-gpg-pub-20240618.asc" -o "$tmpDir/openbao-gpg-pub.asc"
  gpg --import "$tmpDir/openbao-gpg-pub.asc" || true

  if gpg --verify "$tmpDir/openbao.tar.gz.gpgsig" "$tmpDir/openbao.tar.gz"; then
    printf "${GREEN}Signature verification successful\n"
  else
    printf "${RED}Signature verification failed\n"
    # If verification fails but SKIP_VERIFY is set, continue anyway
    if [ "${SKIP_VERIFY:-false}" == "true" ]; then
      printf "${YELLOW}SKIP_VERIFY is set, continuing despite verification failure\n"
    else
      exit 1
    fi
  fi
elif [ ! -s "$tmpDir/openbao.tar.gz.gpgsig" ]; then
  # Already handled above
  :
else
  printf "${YELLOW}GPG not available, skipping signature verification\n"
fi

# Extract the tar file
tar xzf "$tmpDir/openbao.tar.gz" -C "$tmpDir"

# Move files into proper dirs
mv "$tmpDir"/bao usr/local/sbin

# Clean up
rm -Rf "$tmpDir"

# Copy service files
cp ../services/openbao.* usr/local/lib/systemd/system/

# Create extension release
createExtensionRelease openbao-"$latest_version" true
find . -type d -empty -delete
popd > /dev/null || exit 1

if [ "${PUSH}" != false ]; then
  buildAndPush openbao-"$latest_version"
fi

if [ "${KEEP_FILES}" == "false" ];then
  rm -Rf openbao-"$latest_version"
fi

printf "${GREEN}Done\n"
