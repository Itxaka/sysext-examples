#!/usr/bin/env bash

set -ex

source ./shared.sh

# Define service mappings for GitHub Actions workflow
defineServiceMappings "k0scontroller k0sworker"


if [ -n "$K0S_VERSION" ];then
  latest_version="$K0S_VERSION"
else
  latest_version=$(curl -s https://api.github.com/repos/k0sproject/k0s/releases/latest | jq -r '.tag_name')
fi

printf "${GREEN}Using version %s\n" "$latest_version"

arch="amd64"

if [ "$(uname -m)" = "aarch64" ]; then
  arch="arm64"
fi

URL=https://github.com/k0sproject/k0s/releases/download/${latest_version}/k0s-${latest_version}-${arch}

if [ -z "$latest_version" ];then
  exit 1
fi

if [ -d k0s-"$latest_version" ]; then
  if [ "$FORCE" == "false" ];then
    printf "${RED}Version already exists\n"
    exit 0
  fi
  printf "${YELLOW}Version exists but FORCE was set, removing existing version\n"
  rm -Rf k0s-"$latest_version"
fi

mkdir k0s-"$latest_version"
pushd k0s-"$latest_version" > /dev/null || exit 1
createDirs
printf "${GREEN}Downloading k0s\n"
curl -o usr/local/bin/k0s -fsSL "${URL}"
chmod +x usr/local/bin/k0s
printf "${GREEN}Copying service files\n"
cp ../services/k0scontroller.service usr/local/lib/systemd/system/k0scontroller.service
cp ../services/k0sworker.service usr/local/lib/systemd/system/k0sworker.service
createExtensionRelease k0s-"$latest_version" true
# Remove empty dirs
find . -type d -empty -delete
popd > /dev/null || exit 1
if [ "${PUSH}" != false ]; then
  buildAndPush k0s-"$latest_version"
fi
if [ "${KEEP_FILES}" == "false" ];then
  rm -Rf k0s-"$latest_version"
fi
printf "${GREEN}Done\n"