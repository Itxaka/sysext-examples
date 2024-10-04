#!/usr/bin/env bash

set -e

source ./shared.sh



if [ -n "$K9S_VERSION" ];then
  latest_version="$K9S_VERSION"
else
  latest_version=$(curl -s https://api.github.com/repos/derailed/k9s/releases/latest | jq -r '.tag_name')
fi

printf "${GREEN}Using version %s\n" "$latest_version"

URL=https://github.com/derailed/k9s/releases/download/${latest_version}/k9s_Linux_amd64.tar.gz

if [ -z "$latest_version" ];then
  exit 1
fi

if [ -d k9s-"$latest_version" ]; then
  if [ "$FORCE" == "false" ];then
    printf "${RED}Version already exists\n"
    exit 0
  fi
  printf "${YELLOW}Version exists but FORCE was set, removing existing version\n"
  rm -Rf k9s-"$latest_version"
fi

mkdir k9s-"$latest_version"
pushd k9s-"$latest_version" > /dev/null || exit 1
createDirs
printf "${GREEN}Downloading K9S\n"
curl -fsSL "${URL}"| tar xzf - -C usr/local/bin/
chmod +x usr/local/bin/k9s
rm usr/local/bin/LICENSE || true
rm usr/local/bin/README.md || true
createExtensionRelease k9s-"$latest_version" false
# Remove empty dirs
find . -type d -empty -delete
popd > /dev/null || exit 1
if [ "${PUSH}" != false ]; then
  buildAndPush k9s-"$latest_version"
fi
if [ "${KEEP_FILES}" == "false" ];then
  rm -Rf k9s-"$latest_version"
fi
printf "${GREEN}Done\n"