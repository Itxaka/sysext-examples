#!/usr/bin/env bash
#
# Falco system extension script
#
# Based on the falco.sysext from sysext-bakery:
# https://github.com/flatcar/sysext-bakery/tree/main/falco.sysext
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
defineServiceMappings "falco"

if [ -n "$FALCO_VERSION" ]; then
  latest_version="$FALCO_VERSION"
else
  latest_version=$(curl -s https://api.github.com/repos/falcosecurity/falco/releases/latest | jq -r '.tag_name' | grep -v '^v')
fi

printf "${GREEN}Using version %s\n" "$latest_version"

# The release uses different arch identifiers
rel_arch="x86_64"  # Default to x86_64
if [ "$(uname -m)" = "aarch64" ]; then
  rel_arch="aarch64"
fi

URL=https://download.falco.org/packages/bin/${rel_arch}/falco-${latest_version}-${rel_arch}.tar.gz
GPG_SIG_URL=https://download.falco.org/packages/bin/${rel_arch}/falco-${latest_version}-${rel_arch}.tar.gz.asc
GPG_KEY_URL=https://falco.org/repo/falcosecurity-packages.asc

FORCE=${FORCE:-false}

if [ -z "$latest_version" ]; then
  exit 1
fi

if [ -d falco-"$latest_version" ]; then
  if [ "$FORCE" == "false" ]; then
    printf "${RED}Version already exists\n"
    exit 0
  fi
  printf "${YELLOW}Version exists but FORCE was set, removing existing version\n"
  rm -Rf falco-"$latest_version"
fi

mkdir -p falco-"$latest_version"
pushd falco-"$latest_version" > /dev/null || exit 1
createDirs

# Create directories for falco
mkdir -p usr/local/share/falco/etc/
mkdir -p usr/local/lib/tmpfiles.d/

# Download Falco, checksums, and GPG signature
printf "${GREEN}Downloading Falco, checksums, and GPG signature\n"
tmpDir=$(mktemp -d)
curl -fsSL "${URL}" -o "$tmpDir/falco.tar.gz"
# Falco doesn't consistently provide SHA256 files, so we'll skip this
# curl -fsSL "${SHASUM_URL}" -o "$tmpDir/falco.tar.gz.sha256" || true
curl -fsSL "${GPG_SIG_URL}" -o "$tmpDir/falco.tar.gz.asc" || true
curl -fsSL "${GPG_KEY_URL}" -o "$tmpDir/falcosecurity-packages.asc" || true

# Verify GPG signature if gpg is available
if command -v gpg &> /dev/null && [ -f "$tmpDir/falco.tar.gz.asc" ] && [ -f "$tmpDir/falcosecurity-packages.asc" ]; then
  printf "${GREEN}Verifying GPG signature\n"

  # Import the Falco GPG key
  gpg --import "$tmpDir/falcosecurity-packages.asc" 2>/dev/null || true

  # Verify the signature
  if gpg --verify "$tmpDir/falco.tar.gz.asc" "$tmpDir/falco.tar.gz" 2>/dev/null; then
    printf "${GREEN}GPG signature verification successful\n"

  else
    printf "${RED}GPG signature verification failed\n"
    if [ "${SKIP_VERIFY:-false}" == "true" ]; then
      printf "${YELLOW}SKIP_VERIFY is set, continuing despite verification failure\n"
    else
      exit 1
    fi
  fi
else
  printf "${YELLOW}GPG verification not possible, skipping signature verification\n"

  # Since we can't verify, check if we should continue
  if [ "${SKIP_VERIFY:-false}" != "true" ]; then
    printf "${YELLOW}Set SKIP_VERIFY=true to continue without verification\n"
    exit 1
  else
    printf "${YELLOW}SKIP_VERIFY is set, continuing without verification\n"
  fi
fi

# Extract the tar file
printf "${GREEN}Extracting Falco\n"
tar --strip-components 1 -xzf "$tmpDir/falco.tar.gz" -C "$tmpDir"

# Move files into proper dirs
printf "${GREEN}Installing Falco\n"

# Copy configuration files
cp -aR "$tmpDir"/etc/falco usr/local/share/falco/etc/
if [ -d "$tmpDir"/etc/falcoctl ]; then
  cp -aR "$tmpDir"/etc/falcoctl usr/local/share/falco/etc/
fi

# Copy usr directory contents
cp -aR "$tmpDir"/usr/* usr/local/

# Create tmpfiles.d configuration
cat > usr/local/lib/tmpfiles.d/10-falco.conf << EOF
C+ /etc/falco - - - - /usr/local/share/falco/etc/falco
EOF

# Copy service files
if [ -f ../services/falco.service ]; then
  mkdir -p usr/local/lib/systemd/system/
  cp ../services/falco.service usr/local/lib/systemd/system/
fi

# Clean up
rm -Rf "$tmpDir"
createExtensionRelease falco-"$latest_version" true
find . -type d -empty -delete
popd > /dev/null || exit 1
if [ "${PUSH}" != false ]; then
  buildAndPush falco-"$latest_version"
fi
if [ "${KEEP_FILES}" == "false" ]; then
  rm -Rf falco-"$latest_version"
fi
printf "${GREEN}Done\n"
