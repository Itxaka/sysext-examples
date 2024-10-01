#!/usr/bin/env bash

source ./shared.sh

if [ -n "$TAILSCALE_VERSION" ];then
  latest_version="$TAILSCALE_VERSION"
else
  latest_version=$(curl -s https://api.github.com/repos/tailscale/tailscale/releases/latest | jq -r '.tag_name')
fi

printf "${GREEN}Using version %s\n" "$latest_version"

# weird
clean_version="${latest_version#v}"
URL=https://pkgs.tailscale.com/stable/tailscale_${clean_version}_amd64.tgz

FORCE=${FORCE:-false}

if [ -z "$latest_version" ];then
  exit 1
fi

if [ -d tailscale-"$latest_version" ]; then
  if [ "$FORCE" == "false" ];then
    printf "${RED}Version already exists\n"
    exit 0
  fi
  printf "${YELLOW}Version exists but FORCE was set, removing existing version\n"
  rm -Rf ../tailscale-"$latest_version"
fi

mkdir -p tailscale-"$latest_version"
pushd tailscale-"$latest_version" > /dev/null || exit 1
createDirs
# sbctl is compressed
tmpDir=$(mktemp -d)
curl -fsSL "${URL}"| tar xzf - --strip-components=1 -C "$tmpDir"
# move files into proper dirs
mv "$tmpDir"/tailscale usr/local/sbin
mv "$tmpDir"/tailscaled usr/local/sbin
rm -Rf "$tmpDir"
cp ../services/tailscaled.* usr/local/lib/systemd/system/
createExtensionRelease tailscale-"$latest_version" true
find . -type d -empty -delete
popd > /dev/null || exit 1
if [ "${PUSH}" != false ]; then
  buildAndPush tailscale-"$latest_version"
fi
if [ "${KEEP_FILES}" == "false" ];then
  rm -Rf tailscale-"$latest_version"
fi
printf "${GREEN}Done\n"
