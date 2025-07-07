#!/usr/bin/env bash

source ./shared.sh

# Define service mappings for GitHub Actions workflow
defineServiceMappings "nomad"

if [ -n "$NOMAD_VERSION" ];then
  latest_version="$NOMAD_VERSION"
else
  latest_version=$(curl -s https://api.github.com/repos/hashicorp/nomad/releases/latest | jq -r '.tag_name')
fi

printf "${GREEN}Using version %s\n" "$latest_version"

# Remove the 'v' prefix for the file name
version_no_v=${latest_version#v}
URL=https://releases.hashicorp.com/nomad/${version_no_v}/nomad_${version_no_v}_linux_amd64.zip
SHASUM_URL=https://releases.hashicorp.com/nomad/${version_no_v}/nomad_${version_no_v}_SHA256SUMS
SIG_URL=https://releases.hashicorp.com/nomad/${version_no_v}/nomad_${version_no_v}_SHA256SUMS.72D7468F.sig

FORCE=${FORCE:-false}

if [ -z "$latest_version" ];then
  exit 1
fi

if [ -d nomad-"$latest_version" ] && [ "$FORCE" != "true" ];then
  printf "${YELLOW}nomad-${latest_version} already exists, skipping (use FORCE=true to force rebuild)\n"
  exit 0
fi

mkdir -p nomad-"$latest_version"
pushd nomad-"$latest_version" > /dev/null || exit 1
createDirs

# Download Nomad binary, checksums, and signature
printf "${GREEN}Downloading Nomad binary, checksums, and signature\n"
tmpDir=$(mktemp -d)
curl -fsSL "${URL}" -o "$tmpDir/nomad_${version_no_v}_linux_amd64.zip"
curl -fsSL "${SHASUM_URL}" -o "$tmpDir/nomad_SHA256SUMS"
curl -fsSL "${SIG_URL}" -o "$tmpDir/nomad_SHA256SUMS.sig"

# Verify SHA256 checksum
printf "${GREEN}Verifying SHA256 checksum\n"
pushd "$tmpDir" > /dev/null
grep "nomad_${version_no_v}_linux_amd64.zip" nomad_SHA256SUMS | sha256sum -c -
if [ $? -ne 0 ]; then
  printf "${RED}SHA256 checksum verification failed\n"
  exit 1
fi
popd > /dev/null

# Verify GPG signature if gpg is available
if command -v gpg &> /dev/null; then
  printf "${GREEN}Verifying GPG signature\n"

  pushd "$tmpDir" > /dev/null
  # Download and import HashiCorp GPG key
  # HashiCorp Security GPG key
  curl -fsSL "https://www.hashicorp.com/.well-known/pgp-key.txt" -o hashicorp-gpg-key.asc
  gpg --import hashicorp-gpg-key.asc || true

  if gpg --verify nomad_SHA256SUMS.sig nomad_SHA256SUMS; then
    printf "${GREEN}GPG signature verification successful\n"
  else
    printf "${RED}GPG signature verification failed\n"
    if [ "${SKIP_VERIFY:-false}" == "true" ]; then
      printf "${YELLOW}SKIP_VERIFY is set, continuing despite verification failure\n"
    else
      exit 1
    fi
  fi
  popd > /dev/null
else
  printf "${YELLOW}GPG not available, skipping signature verification\n"
fi

# Extract the zip file
unzip -q "$tmpDir/nomad_${version_no_v}_linux_amd64.zip" -d "$tmpDir"

# Move binary into proper directory
mv "$tmpDir"/nomad usr/local/bin/
chmod +x usr/local/bin/nomad

# Clean up
rm -Rf "$tmpDir"

# Copy service files
cp ../services/nomad.* usr/local/lib/systemd/system/

# Create extension release
createExtensionRelease nomad-"$latest_version" true
find . -type d -empty -delete
popd > /dev/null || exit 1

if [ "${PUSH}" != false ]; then
  buildAndPush nomad-"$latest_version"
fi

if [ "${KEEP_FILES}" == "false" ];then
  rm -Rf nomad-"$latest_version"
fi

printf "${GREEN}Done\n"
