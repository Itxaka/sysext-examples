#!/usr/bin/env bash

set -e

source ./shared.sh



if [ -n "$HELM_VERSION" ];then
  latest_version="$HELM_VERSION"
else
  latest_version=$(curl -s https://api.github.com/repos/helm/helm/releases/latest | jq -r '.tag_name')
fi

printf "${GREEN}Using version %s\n" "$latest_version"

URL=https://get.helm.sh/helm-${latest_version}-linux-amd64.tar.gz

if [ -z "$latest_version" ];then
  exit 1
fi

if [ -d helm-"$latest_version" ]; then
  if [ "$FORCE" == "false" ];then
    printf "${RED}Version already exists\n"
    exit 0
  fi
  printf "${YELLOW}Version exists but FORCE was set, removing existing version\n"
  rm -Rf helm-"$latest_version"
fi

mkdir helm-"$latest_version"
pushd helm-"$latest_version" > /dev/null || exit 1
createDirs
printf "${GREEN}Downloading helm\n"
curl -fsSL "${URL}"| tar xzf - --strip-components=1 -C usr/local/bin/
chmod +x usr/local/bin/helm
rm usr/local/bin/LICENSE
rm usr/local/bin/README.md
createExtensionRelease helm-"$latest_version" false
# Remove empty dirs
find . -type d -empty -delete
popd > /dev/null || exit 1
if [ "${PUSH}" != false ]; then
  buildAndPush helm-"$latest_version"
fi
if [ "${KEEP_FILES}" == "false" ];then
  rm -Rf helm-"$latest_version"
fi
printf "${GREEN}Done\n"