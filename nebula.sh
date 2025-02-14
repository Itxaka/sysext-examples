#!/usr/bin/env bash

source ./shared.sh

if [ -n "$NEBULA_VERSION" ];then
  latest_version="$NEBULA_VERSION"
else
  latest_version=$(curl -s https://api.github.com/repos/slackhq/nebula/releases/latest | jq -r '.tag_name')
fi

printf "${GREEN}Using version %s\n" "$latest_version"

URL=https://github.com/slackhq/nebula/releases/download/${latest_version}/nebula-linux-amd64.tar.gz

FORCE=${FORCE:-false}

if [ -z "$latest_version" ];then
  exit 1
fi

if [ -d nebula-"$latest_version" ]; then
  if [ "$FORCE" == "false" ];then
    printf "${RED}Version already exists\n"
    exit 0
  fi
  printf "${YELLOW}Version exists but FORCE was set, removing existing version\n"
  rm -Rf ../nebula-"$latest_version"
fi

mkdir -p nebula-"$latest_version"
pushd nebula-"$latest_version" > /dev/null || exit 1
createDirs
# Nebula is compressed
tmpDir=$(mktemp -d)
curl -fsSL "${URL}"| tar xzf - -C "$tmpDir"
# move files into proper dirs
mv "$tmpDir"/nebula usr/local/sbin
#If you need nebula-cert on your system, move it here too
#mv "$tmpDir"/nebula-cert usr/local/sbin
rm -Rf "$tmpDir"
cp ../services/nebula.* usr/local/lib/systemd/system/
createExtensionRelease nebula-"$latest_version" true
find . -type d -empty -delete
popd > /dev/null || exit 1
if [ "${PUSH}" != false ]; then
  buildAndPush nebula-"$latest_version"
fi
if [ "${KEEP_FILES}" == "false" ];then
  rm -Rf nebula-"$latest_version"
fi
printf "${GREEN}Done\n"
