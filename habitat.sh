#!/usr/bin/env bash
#
# habitat.sh
#
# This script downloads the latest Habitat package (or a specified version)
# from packages.chef.io and installs it as a system extension.
#

# Source shared functions (createDirs, createExtensionRelease, buildAndPush, etc.)
source ./shared.sh

# Set color variables if they’re not defined in shared.sh
GREEN=${GREEN:-"\033[0;32m"}
YELLOW=${YELLOW:-"\033[0;33m"}
RED=${RED:-"\033[0;31m"}
NC=${NC:-"\033[0m"}  # No Color

# Determine the Habitat version to download.
# If HABITAT_VERSION is provided, use that in the URL;
# otherwise, use "latest" (the tarball will still contain a folder with a real version).
if [ -n "$HABITAT_VERSION" ]; then
  download_version="$HABITAT_VERSION"
else
  download_version="latest"
fi

printf "${GREEN}Requesting Habitat version '%s'${NC}\n" "$download_version"

# Use environment variable HABITAT_CHANNEL if set; otherwise default to stable.
channel=${HABITAT_CHANNEL:-stable}

# For Linux AMD64, set target accordingly.
target="x86_64-linux"

# We assume a tar.gz archive on Linux.
ext="tar.gz"

# Build the URL for downloading Habitat.
if [ "$download_version" == "latest" ]; then
  URL="https://packages.chef.io/files/${channel}/habitat/latest/hab-${target}.${ext}"
else
  URL="https://packages.chef.io/files/habitat/${download_version}/hab-${target}.${ext}"
fi

printf "${GREEN}Downloading Habitat from: %s${NC}\n" "$URL"

# Create a temporary directory for download and extraction.
tmpDir=$(mktemp -d)

# Download the tarball.
tarball="${tmpDir}/hab.tar.gz"
curl -fsSL "${URL}" -o "$tarball"

# Extract the tarball into a temporary 'extracted' directory.
extractedDir="${tmpDir}/extracted"
mkdir -p "$extractedDir"
tar xzf "$tarball" -C "$extractedDir"

# Identify the top-level directory from the tarball.
# We assume the tarball extracts a single folder like:
#   hab-1.6.1243-20241227194506-x86_64-linux
folder=$(find "$extractedDir" -mindepth 1 -maxdepth 1 -type d | head -n 1)
if [ -z "$folder" ]; then
  printf "${RED}Failed to extract Habitat tarball or find top-level folder.${NC}\n"
  exit 1
fi

# Parse the version number from the folder name.
# Example folder basename: hab-1.6.1243-20241227194506-x86_64-linux
folderBase=$(basename "$folder")
# This uses '-' as a delimiter and picks field 2.
parsed_version=$(echo "$folderBase" | cut -d '-' -f2)
if [ -z "$parsed_version" ]; then
  printf "${RED}Could not parse version from folder name: %s${NC}\n" "$folderBase"
  exit 1
fi

printf "${GREEN}Extracted Habitat version: %s${NC}\n" "$parsed_version"

# Define the working directory for the system extension using the parsed version.
sysext_dir="habitat-${parsed_version}"

# FORCE flag (if set to true, overwrite an existing directory)
FORCE=${FORCE:-false}

if [ -d "$sysext_dir" ]; then
  if [ "$FORCE" == "false" ]; then
    printf "${RED}Directory for version %s already exists; use FORCE=true to override.${NC}\n" "$parsed_version"
    exit 0
  else
    printf "${YELLOW}Directory for version %s exists but FORCE is set; removing existing directory.${NC}\n" "$parsed_version"
    rm -Rf "$sysext_dir"
  fi
fi

# Create and switch into the working directory for this version.
mkdir -p "$sysext_dir"
pushd "$sysext_dir" > /dev/null || exit 1

# Create the directory structure for the extension.
# (createDirs should create directories like usr/local/sbin and usr/local/lib/systemd/system)
createDirs

# Move the hab binary from the extracted folder into usr/local/sbin.
if [ -f "$folder/hab" ]; then
  mv "$folder/hab" usr/local/sbin/
else
  printf "${RED}hab binary not found in extracted folder: %s${NC}\n" "$folder"
  exit 1
fi

# Copy systemd service files if they exist.
if [ -d ../services ]; then
  if compgen -G "../services/habitat.*" > /dev/null; then
    cp ../services/habitat.* usr/local/lib/systemd/system/
  fi
fi

# Create the system extension release using the parsed version.
createExtensionRelease "$sysext_dir" true

# Remove any empty directories.
find . -type d -empty -delete

popd > /dev/null || exit 1

# Optionally, build and push the extension.
if [ "${PUSH}" != false ]; then
  buildAndPush "$sysext_dir"
fi

# Optionally, remove the working directory.
if [ "${KEEP_FILES}" == "false" ]; then
  rm -Rf "$sysext_dir"
fi

# Clean up the temporary download directory.
rm -Rf "$tmpDir"

printf "${GREEN}Habitat sysext installation complete (version: %s)!${NC}\n" "$parsed_version"
