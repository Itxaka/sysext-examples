#!/usr/bin/env bash

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'

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

if [ -d ../../k3s-"$latest_version" ]; then
  if [ "$FORCE" == "false" ];then
    printf "${RED}Version already exists\n"
    exit 1
  fi
  printf "${YELLOW}Version exists but FORCE was set, removing existing version\n"
  rm -Rf ../../k3s-"$latest_version"
fi

mkdir k3s-"$latest_version"
pushd k3s-"$latest_version" > /dev/null || exit 1
mkdir -p usr/local/bin
pushd usr/local/bin > /dev/null || exit 1
printf "${GREEN}Downloading k3s\n"
curl -o k3s -fsSL "${URL}"
chmod +x ./k3s
printf "${GREEN}Creating symlinks\n"
ln -s ./k3s kubectl
ln -s ./k3s ctr
ln -s ./k3s crictl
popd > /dev/null || exit 1
mkdir -p usr/local/lib/systemd/system/
printf "${GREEN}Copying service files\n"
cp ../k3s.service usr/local/lib/systemd/system/k3s.service
cp ../k3s-agent.service usr/local/lib/systemd/system/k3s-agent.service
printf "${GREEN}Creating extension.release.k3s-%s file\n" "$latest_version"
mkdir -p usr/lib/extension-release.d/
printf "ID=_any\nARCHITECTURE=x86-64\nEXTENSION_RELOAD_MANAGER=1\n" > usr/lib/extension-release.d/extension-release.k3s-"$latest_version"
popd > /dev/null || exit 1
mv k3s-"$latest_version" ../../
printf "${GREEN}Done\n"