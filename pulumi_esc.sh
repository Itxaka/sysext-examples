#!/usr/bin/env bash

source ./shared.sh

if [ -n "$PULUMI_ESC_VERSION" ];then
  latest_version="$PULUMI_ESC_VERSION"
else
  latest_version=$(curl -s https://api.github.com/repos/pulumi/esc/releases/latest | jq -r '.tag_name')
fi

printf "${GREEN}Using version %s\n" "$latest_version"

URL=https://github.com/pulumi/esc/releases/download/${latest_version}/esc-${latest_version}-linux-x64.tar.gz

FORCE=${FORCE:-false}

if [ -z "$latest_version" ];then
  exit 1
fi

if [ -d pulumi_esc-"$latest_version" ]; then
  if [ "$FORCE" == "false" ];then
    printf "${RED}Version already exists\n"
    exit 0
  fi
  printf "${YELLOW}Version exists but FORCE was set, removing existing version\n"
  rm -Rf ../pulumi_esc-"$latest_version"
fi

mkdir -p pulumi_esc-"$latest_version"
pushd pulumi_esc-"$latest_version" > /dev/null || exit 1
createDirs
# pulumi_esc is compressed
tmpDir=$(mktemp -d)
curl -fsSL "${URL}"| tar xzf - --strip-components=1 -C "$tmpDir"
# move files into proper dirs
mv "$tmpDir"/esc usr/local/sbin
rm -Rf "$tmpDir"
# Copy systemd service files if they exist.
if [ -d ../services ]; then
  if compgen -G "../services/pulumi_esc.*" > /dev/null; then
    cp ../services/pulumi_esc.* usr/local/lib/systemd/system/
  fi
fi
createExtensionRelease pulumi_esc-"$latest_version" true
find . -type d -empty -delete
popd > /dev/null || exit 1
if [ "${PUSH}" != false ]; then
  buildAndPush pulumi_esc-"$latest_version"
fi
if [ "${KEEP_FILES}" == "false" ];then
  rm -Rf pulumi_esc-"$latest_version"
fi
printf "${GREEN}Done\n"
