RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'

REPOSITORY=${REPOSITORY:-"ttl.sh"}
PUSH=${PUSH:-"false"}
KEEP_FILES=${KEEP_FILES:-"true"}
FORCE=${FORCE:-false}
K3S_VERSION=${K3S_VERSION:-}
SBCTL_VERSION=${SBCTL_VERSION:-}
TAILSCALE_VERSION=${TAILSCALE_VERSION:-}
HELM_VERSION=${HELM_VERSION:-}

if [[ "${KEEP_FILES}" == "false" && "${PUSH}" == "false" ]]; then
  printf "${RED}Both KEEP_FILES and PUSH are set to false. Please choose one or the other.\n"
  exit 0
fi

# all this functions are expected to be run inside the directory with the proper name-version
createDirs() {
    mkdir -p usr/local/bin
    mkdir -p usr/local/sbin
    mkdir -p usr/local/lib/systemd/system/
    mkdir -p usr/lib/extension-release.d/
}

createExtensionRelease() {
  local name=$1
  local RELOAD=$2

  printf "${GREEN}Creating extension.release.%s file with reload: %s\n" "${name}" "${RELOAD}"
  printf "ID=_any\nARCHITECTURE=x86-64\n" > usr/lib/extension-release.d/extension-release."${name}"
  if [ "$RELOAD" == "true" ]; then
    printf "EXTENSION_RELOAD_MANAGER=1\n" >> usr/lib/extension-release.d/extension-release."${name}"
  fi

}

# This one is expected to be run from outside the dir with he dir as the argument so it
# can split it and get the name and version for the docker image
buildAndPush() {
  local dir=$1
  if [ ! -d "${dir}/usr/" ]; then
      echo "$dir doesnt look like a sysextension, skipping"
  fi
  name=$(echo "${dir%/}" | cut -d'-' -f1)
  version=$(echo "${dir%/}" | cut -d'-' -f2)
  if [ -z "$version" ]; then
      version="latest"
  fi
  # Replace + with _
  docker_version=$(echo "$version" | tr '+' '_')
  # Ensure it's lowercase
  docker_version=$(echo "$docker_version" | tr '[:upper:]' '[:lower:]')
  pushd "$dir" > /dev/null || exit 1
  cat <<EOF > .dockerignore
Dockerfile
EOF
  cat <<EOF > Dockerfile
FROM scratch
COPY . /
EOF
  docker build -t "$REPOSITORY"/"$name":"$docker_version" .
  rm Dockerfile
  rm .dockerignore
  if [ "$PUSH" = "true" ]; then
      docker push "$REPOSITORY"/"$name":"$docker_version"
  fi
  popd > /dev/null || exit 1
}