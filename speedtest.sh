#!/usr/bin/env bash

source ./shared.sh

if [ -n "$SPEEDTEST_VERSION" ];then
  latest_version="$SPEEDTEST_VERSION"
else
  latest_version="1.2.0"  # Default to 1.2.0 as there's no API to get the latest version
fi

printf "${GREEN}Using version %s\n" "$latest_version"

URL=https://install.speedtest.net/app/cli/ookla-speedtest-${latest_version}-linux-x86_64.tgz

FORCE=${FORCE:-false}

if [ -d speedtest-"$latest_version" ]; then
  if [ "$FORCE" == "false" ];then
    printf "${RED}Version already exists\n"
    exit 0
  fi
  printf "${YELLOW}Version exists but FORCE was set, removing existing version\n"
  rm -Rf speedtest-"$latest_version"
fi

mkdir -p speedtest-"$latest_version"
pushd speedtest-"$latest_version" > /dev/null || exit 1
createDirs

# Create man and doc directories
printf "${GREEN}Creating man and doc directories\n"
mkdir -p usr/local/share/man/man5
mkdir -p usr/local/share/doc/speedtest

# Download Speedtest CLI
printf "${GREEN}Downloading Speedtest CLI\n"
tmpDir=$(mktemp -d)
curl -fsSL "${URL}" -o "$tmpDir/speedtest.tgz"

# Extract the tar file
printf "${GREEN}Extracting Speedtest CLI\n"
tar xzf "$tmpDir/speedtest.tgz" -C "$tmpDir"

# Move files into proper dirs
printf "${GREEN}Installing Speedtest CLI\n"
mv "$tmpDir/speedtest" usr/local/bin/
mv "$tmpDir/speedtest.5" usr/local/share/man/man5/
mv "$tmpDir/speedtest.md" usr/local/share/doc/speedtest/
chmod +x usr/local/bin/speedtest

# Clean up
rm -Rf "$tmpDir"

# Create extension release
printf "${GREEN}Creating extension release\n"
createExtensionRelease speedtest-"$latest_version" false
find . -type d -empty -delete
popd > /dev/null || exit 1

if [ "${PUSH}" != false ]; then
  buildAndPush speedtest-"$latest_version"
fi

if [ "${KEEP_FILES}" == "false" ];then
  rm -Rf speedtest-"$latest_version"
fi

printf "${GREEN}Done\n"
