#!/usr/bin/env bash

source ./shared.sh


if [ -n "$SBCTL_VERSION" ];then
  latest_version="$SBCTL_VERSION"
else
  latest_version=$(curl -s https://api.github.com/repos/Foxboron/sbctl/releases/latest | jq -r '.tag_name')
fi

printf "${GREEN}Using version %s\n" "$latest_version"

URL=https://github.com/Foxboron/sbctl/releases/download/${latest_version}/sbctl-${latest_version}-linux-amd64.tar.gz
FORCE=${FORCE:-false}

if [ -z "$latest_version" ];then
  exit 1
fi

if [ -d sbctl-"$latest_version" ]; then
  if [ "$FORCE" == "false" ];then
    printf "${RED}Version already exists\n"
    exit 0
  fi
  printf "${YELLOW}Version exists but FORCE was set, removing existing version\n"
  rm -Rf sbctl-"$latest_version"
fi

mkdir -p sbctl-"$latest_version"
pushd sbctl-"$latest_version" > /dev/null || exit 1
createDirs
# sbctl is compressed
curl -fsSL "${URL}"| tar xzf - --strip-components=1 -C usr/local/bin/
# cleanup
rm usr/local/bin/LICENSE
createExtensionRelease sbctl-"$latest_version" false
find . -type d -empty -delete
popd > /dev/null || exit 1
if [ "${PUSH}" != false ]; then
  buildAndPush sbctl-"$latest_version"
fi
if [ "${KEEP_FILES}" != "false" ];then
  rm -Rf sbctl-"$latest_version"
fi
printf "${GREEN}Done\n"