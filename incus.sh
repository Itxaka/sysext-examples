#!/usr/bin/env bash
set -e

source ./shared.sh

# -----------------------------------------------------------------------------
# Add the stable repository for incus to the runner
# -----------------------------------------------------------------------------
printf "${GREEN}Adding stable incus repository...\n"

# Create keyrings directory if not exists.
sudo mkdir -p /etc/apt/keyrings

# Download and store the repository key.
curl -fsSL https://pkgs.zabbly.com/key.asc | sudo tee /etc/apt/keyrings/zabbly.asc > /dev/null

# Write the repository source file.
sudo sh -c 'cat <<EOF > /etc/apt/sources.list.d/zabbly-incus-stable.sources
Enabled: yes
Types: deb
URIs: https://pkgs.zabbly.com/incus/stable
Suites: $(. /etc/os-release && echo ${VERSION_CODENAME})
Components: main
Architectures: $(dpkg --print-architecture)
Signed-By: /etc/apt/keyrings/zabbly.asc
EOF'


# Incus systemd-extension build script for ubuntu24.04 (amd64).
# Automatically pulls the latest incus-base and incus packages from the stable repo.

# Update apt cache using sudo.
sudo apt-get update -qq

# Clean up any leftover directories with a colon in the name (e.g., "incus-1:6.10.1-ubuntu24.04-202503030403")
for d in incus-1:*; do
  if [ -d "$d" ]; then
    printf "${YELLOW}Cleaning up leftover directory: %s\n" "$d"
    rm -rf "$d"
  fi
done

printf "${GREEN}Determining the latest incus-base version...\n"
# Find the package version containing "ubuntu24.04" and "amd64"
latest_deb_ver=$(apt-cache madison incus-base | grep 'ubuntu24.04' | grep 'amd64' | head -n 1 | awk '{print $3}')
if [ -z "$latest_deb_ver" ]; then
  printf "${RED}Could not detect a valid incus-base version for ubuntu24.04 amd64.\n"
  exit 1
fi
printf "${GREEN}Latest version in repo is: %s\n" "$latest_deb_ver"

# Use the full package version for downloading.
full_version="$latest_deb_ver"

# Remove any epoch from the version if present.
if [[ "$full_version" == *:* ]]; then
  stripped_version="${full_version#*:}"
else
  stripped_version="$full_version"
fi

# Use only the part before the first dash as the truncated upstream version.
version=$(echo "$stripped_version" | cut -d'-' -f1)
printf "${GREEN}Using truncated version: %s\n" "$version"

# Encode the colon for file matching (replace ":" with "%3a")
encoded_full_version=$(echo "$full_version" | sed 's/:/%3a/g')

# Create a clean working directory for the sysext.
ext_dir="incus-$version"
rm -rf "$ext_dir"
mkdir "$ext_dir"
pushd "$ext_dir" > /dev/null

# Download incus-base and incus using the full version.
printf "${GREEN}Downloading packages incus-base=%s and incus=%s...\n" "$full_version" "$full_version"
apt-get download "incus-base=$full_version" "incus=$full_version"

# Create temporary directories for extraction.
mkdir tmp-base tmp-incus

# Locate the downloaded deb files. (They encode the colon as %3a.)
deb_base=$(ls incus-base_*_amd64.deb 2>/dev/null | grep "$encoded_full_version" | head -n1)
deb_incus=$(ls incus_*_amd64.deb 2>/dev/null | grep "$encoded_full_version" | head -n1)

if [ -z "$deb_base" ] || [ -z "$deb_incus" ]; then
  printf "${RED}Failed to find downloaded deb packages for version %s\n" "$full_version"
  exit 1
fi

dpkg-deb -x "$deb_base" tmp-base
dpkg-deb -x "$deb_incus" tmp-incus

# Merge the contents (files from the incus package override incus-base if overlapping).
cp -a tmp-base/* .
cp -a tmp-incus/* .

# --- Adjust the filesystem tree to be sysext-friendly ---

# 1. Move systemd unit files from ./lib/systemd/system/ to ./usr/local/lib/systemd/system/
if [ -d lib/systemd/system ]; then
  mkdir -p usr/local/lib/systemd/system/
  mv lib/systemd/system/* usr/local/lib/systemd/system/
fi
rm -rf lib

# 2. Remove the documentation directory under ./opt/incus/doc/
rm -rf opt/incus/doc

# 3. Move the sysctl configuration from ./etc/sysctl.d/ to ./usr/lib/sysctl.d/
if [ -d etc/sysctl.d ] && [ -f etc/sysctl.d/50-incus.conf ]; then
  mkdir -p usr/lib/sysctl.d
  mv etc/sysctl.d/50-incus.conf usr/lib/sysctl.d/50-incus.conf
fi

# 4. Remove the rest of the ./etc directory.
rm -rf etc

# 5. Remove the ./var directory entirely.
rm -rf var

# 6. Remove the ./usr/bin directory (binaries are provided under /opt).
rm -rf usr/bin

# Ensure the extension release directory exists.
mkdir -p usr/lib/extension-release.d

# Clean up temporary directories and the downloaded deb files.
rm -rf tmp-base tmp-incus
rm -f "$deb_base" "$deb_incus"

# Create the extension release metadata file.
createExtensionRelease incus-"$version" true

# Remove any empty directories.
find . -type d -empty -delete

popd > /dev/null || exit 1

# Optionally build and push a Docker image.
if [ "${PUSH}" != "false" ]; then
  buildAndPush "$ext_dir"
fi

# Optionally clean up the sysext directory.
if [ "${KEEP_FILES}" == "false" ]; then
  rm -rf "$ext_dir"
fi

# Clean up any leftover directories with a colon in the name (e.g., "incus-1:6.10.1-ubuntu24.04-202503030403")
for d in incus-1:*; do
  if [ -d "$d" ]; then
    printf "${YELLOW}Cleaning up leftover directory: %s\n" "$d"
    rm -rf "$d"
  fi
done

printf "${GREEN}Done! Sysext created in %s\n" "$ext_dir"
