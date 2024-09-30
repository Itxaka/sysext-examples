RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'

# all this functions are expected to be run inside an empty directory with he proper name-version

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

downloadArtifact() {
  local url=$1
  local destination=$2
  printf "${GREEN}Downloading %s\n" "${destination}"
  curl -o usr/local/bin/"${destination}" -fsSL "${url}"
  chmod +x usr/local/bin/"${destination}"
}