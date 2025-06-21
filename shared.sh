RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'

REPOSITORY=${REPOSITORY:-"ttl.sh"}
PUSH=${PUSH:-"false"}
KEEP_FILES=${KEEP_FILES:-"true"}
FORCE=${FORCE:-false}
SKIP_VERIFY=${SKIP_VERIFY:-false}
SKIP_DEPS=${SKIP_DEPS:-false}
K3S_VERSION=${K3S_VERSION:-}
SBCTL_VERSION=${SBCTL_VERSION:-}
TAILSCALE_VERSION=${TAILSCALE_VERSION:-}
NEBULA_VERSION=${NEBULA_VERSION:-}
HELM_VERSION=${HELM_VERSION:-}
K9S_VERSION=${K9S_VERSION:-}
HABITAT_VERSION=${HABITAT_VERSION:-}
PULUMI_ESC_VERSION=${PULUMI_ESC_VERSION:-}
OPENBAO_VERSION=${OPENBAO_VERSION:-}
ALLOY_VERSION=${ALLOY_VERSION:-}
SPEEDTEST_VERSION=${SPEEDTEST_VERSION:-}
MINIUPNPC_VERSION=${MINIUPNPC_VERSION:-}
DOCKER_VERSION=${DOCKER_VERSION:-}
DOCKER_COMPOSE_VERSION=${DOCKER_COMPOSE_VERSION:-}
FALCO_VERSION=${FALCO_VERSION:-}
LIBRESPEED_CLI_VERSION=${LIBRESPEED_CLI_VERSION:-}
SYSBOX_VERSION=${SYSBOX_VERSION:-}
HABITAT_CHANNEL=${HABITAT_CHANNEL:-stable}


# Check if this is a service mappings query
if [[ "$1" == "--get-service-mappings" ]]; then
  # If .service-mappings file exists, output its contents
  if [[ -f .service-mappings ]]; then
    cat .service-mappings
  fi
  exit 0
fi

set -e

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
  # Get the full directory name without trailing slash
  dir_name="${dir%/}"

  # Handle special cases for system extensions with dashes in their names first
  for sysext in "docker-compose" "pulumi-esc" "pulumi_esc" "librespeed-cli"; do
    if [[ "$dir_name" == "$sysext-"* ]]; then
      name="$sysext"
      version="${dir_name#$sysext-}"
      break
    fi
  done

  # If not a special case, use the standard approach
  if [ -z "$name" ]; then
    # Find the position of the last dash
    last_dash_pos=$(echo "$dir_name" | grep -bo '-' | tail -1 | cut -d':' -f1)

    if [ -n "$last_dash_pos" ]; then
      # Extract the name (everything before the last dash)
      name="${dir_name:0:$last_dash_pos}"

      # Extract the version (everything after the last dash)
      version="${dir_name:$((last_dash_pos+1))}"
    else
      # No dash found, use the whole name
      name="$dir_name"
      version=""
    fi
  fi

  if [ -z "$version" ]; then
      version="latest"
  fi
  # Replace + with _
  docker_version=$(echo "$version" | tr '+' '_')
  # Ensure it's lowercase
  docker_version=$(echo "$docker_version" | tr '[:upper:]' '[:lower:]')

  # Debug output
  echo "Building image for: $dir"
  echo "  Name: $name"
  echo "  Version: $version"
  echo "  Docker tag: $docker_version"

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

# Function to define service mappings for GitHub Actions workflow
# This is used to determine which service files are associated with this system extension
# Usage: defineServiceMappings "service1 service2 service3"
defineServiceMappings() {
  local mappings=$1

  # Create a .service-mappings file in the root directory
  # This file will be read by the GitHub Actions workflow
  echo "$mappings" > .service-mappings
}