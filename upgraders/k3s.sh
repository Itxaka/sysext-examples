#!/usr/bin/env bash

set -e

source ./shared.sh


K3S_VERSION=${K3S_VERSION:-}
if [ -n "$K3S_VERSION" ];then
  latest_version="$K3S_VERSION"
else
  latest_version=$(curl -s https://api.github.com/repos/k3s-io/k3s/releases/latest | jq -r '.tag_name')
fi

printf "${GREEN}Using version %s\n" "$latest_version"

URL=https://github.com/k3s-io/k3s/releases/download/${latest_version}/k3s
FORCE=${FORCE:-false}

if [ -z "$latest_version" ];then
  exit 1
fi

if [ -d ../k3s-"$latest_version" ]; then
  if [ "$FORCE" == "false" ];then
    printf "${RED}Version already exists\n"
    exit 0
  fi
  printf "${YELLOW}Version exists but FORCE was set, removing existing version\n"
  rm -Rf ../k3s-"$latest_version"
fi

mkdir k3s-"$latest_version"
pushd k3s-"$latest_version" > /dev/null || exit 1
createDirs
printf "${GREEN}Downloading k3s\n"
curl -o usr/local/bin/k3s -fsSL "${URL}"
chmod +x usr/local/bin/k3s
printf "${GREEN}Creating symlinks\n"
ln -s ./k3s usr/local/bin/kubectl
ln -s ./k3s usr/local/bin/ctr
ln -s ./k3s usr/local/bin/crictl
printf "${GREEN}Copying service files\n"
cp ../services/k3s.service usr/local/lib/systemd/system/k3s.service
cp ../services/k3s-agent.service usr/local/lib/systemd/system/k3s-agent.service
createExtensionRelease k3s-"$latest_version" true
# Remove empty dirs
find . -type d -empty -delete
popd > /dev/null || exit 1
mv k3s-"$latest_version" ../
printf "${GREEN}Done\n"