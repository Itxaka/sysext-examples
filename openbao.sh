#!/usr/bin/env bash

source ./shared.sh

if [ -n "$OPENBAO_VERSION" ];then
  latest_version="$OPENBAO_VERSION"
else
  latest_version=$(curl -s https://api.github.com/repos/openbao/openbao/releases/latest | jq -r '.tag_name')
fi

printf "${GREEN}Using version %s\n" "$latest_version"

# Remove the 'v' prefix for the file name
version_no_v=${latest_version#v}
URL=https://github.com/openbao/openbao/releases/download/${latest_version}/bao_${version_no_v}_Linux_x86_64.tar.gz
SIG_URL=https://github.com/openbao/openbao/releases/download/${latest_version}/bao_${version_no_v}_Linux_x86_64.tar.gz.sig

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
curl -fsSL "${SIG_URL}" -o "$tmpDir/openbao.tar.gz.sig"

# Verify signature if gpg is available
if command -v gpg &> /dev/null; then
  printf "${GREEN}Verifying signature\n"
  # Import OpenBao GPG key if needed
  # Note: In a production environment, you should verify the key fingerprint
  gpg --keyserver keyserver.ubuntu.com --recv-keys 0x6A2D74F1986F7CAB || true
  
  if gpg --verify "$tmpDir/openbao.tar.gz.sig" "$tmpDir/openbao.tar.gz"; then
    printf "${GREEN}Signature verification successful\n"
  else
    printf "${RED}Signature verification failed\n"
    exit 1
  fi
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
