#!/usr/bin/env bash
#
# Docker system extension script
#
# Based on the docker.sysext from sysext-bakery:
# https://github.com/flatcar/sysext-bakery/tree/main/docker.sysext
#
# Original work Copyright 2023 The Flatcar Maintainers
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

source ./shared.sh

# Define service mappings for GitHub Actions workflow
defineServiceMappings "docker containerd docker.socket"

if [ -n "$DOCKER_VERSION" ]; then
  latest_version="$DOCKER_VERSION"
else
  latest_version=$(curl -fsSL https://download.docker.com/linux/static/stable/x86_64/ | sed -n 's/.*docker-\([0-9.]\+\).tgz.*/\1/p' | sort -Vr | head -1)
fi

printf "${GREEN}Using version %s\n" "$latest_version"

URL=https://download.docker.com/linux/static/stable/x86_64/docker-${latest_version}.tgz
# Docker doesn't provide consistent checksums, so we'll calculate it ourselves

FORCE=${FORCE:-false}

if [ -z "$latest_version" ]; then
  exit 1
fi

if [ -d docker-"$latest_version" ]; then
  if [ "$FORCE" == "false" ]; then
    printf "${RED}Version already exists\n"
    exit 0
  fi
  printf "${YELLOW}Version exists but FORCE was set, removing existing version\n"
  rm -Rf docker-"$latest_version"
fi

mkdir -p docker-"$latest_version"
pushd docker-"$latest_version" > /dev/null || exit 1
createDirs

# Create directories for containerd config
mkdir -p usr/local/share/containerd
mkdir -p usr/local/lib/systemd/system/multi-user.target.d
mkdir -p usr/local/lib/systemd/system/sockets.target.d

# Download Docker
printf "${GREEN}Downloading Docker\n"
tmpDir=$(mktemp -d)
curl -fsSL "${URL}" -o "$tmpDir/docker.tgz"

# Since Docker doesn't provide consistent checksums, we'll skip verification
printf "${YELLOW}Docker doesn't provide consistent checksums, skipping verification\n"

# Extract the tar file
printf "${GREEN}Extracting Docker\n"
tar xzf "$tmpDir/docker.tgz" -C "$tmpDir"

# Move files into proper dirs
printf "${GREEN}Installing Docker\n"
cp -a "$tmpDir"/docker/* usr/local/bin/
ls -la usr/local/bin/

# Create containerd config
cat > usr/local/share/containerd/config.toml << EOF
version = 2
# set containerd's OOM score
oom_score = -999
[plugins."io.containerd.grpc.v1.cri".containerd.runtimes.runc]
# setting runc.options unsets parent settings
runtime_type = "io.containerd.runc.v2"
[plugins."io.containerd.grpc.v1.cri".containerd.runtimes.runc.options]
SystemdCgroup = true
EOF

# Copy systemd service files
cp ../services/containerd.service usr/local/lib/systemd/system/
cp ../services/docker.service usr/local/lib/systemd/system/
cp ../services/docker.socket usr/local/lib/systemd/system/
cp ../services/docker.defaults usr/local/lib/systemd/system/

cat > usr/local/lib/systemd/system/multi-user.target.d/10-containerd-service.conf << EOF
[Unit]
Wants=containerd.service
EOF

cat > usr/local/lib/systemd/system/sockets.target.d/10-docker-socket.conf << EOF
[Unit]
Wants=docker.socket
EOF

# Clean up
rm -Rf "$tmpDir"
createExtensionRelease docker-"$latest_version" true
find . -type d -empty -delete
popd > /dev/null || exit 1
if [ "${PUSH}" != false ]; then
  buildAndPush docker-"$latest_version"
fi
if [ "${KEEP_FILES}" == "false" ]; then
  rm -Rf docker-"$latest_version"
fi
printf "${GREEN}Done\n"
