#!/usr/bin/env bash

# Enable debug directly
set -euo pipefail

source ./shared.sh

# Install Go if not available
install_go() {
  local go_version="1.22.6"
  local arch="amd64"

  if [ "$(uname -m)" = "aarch64" ]; then
    arch="arm64"
  fi

  printf "${GREEN}Installing Go ${go_version}\n"
  local go_tar="go${go_version}.linux-${arch}.tar.gz"

  # Download Go
  if ! curl -fsSL "https://go.dev/dl/${go_tar}" -o "${go_tar}"; then
    printf "${RED}Failed to download Go\n"
    exit 1
  fi

  # Install Go
  if ! sudo tar -C /usr/local -xzf "${go_tar}"; then
    printf "${RED}Failed to install Go\n"
    exit 1
  fi

  # Clean up
  rm -f "${go_tar}"

  # Add Go to PATH for this session
  export PATH=$PATH:/usr/local/go/bin
  export GOPATH=$HOME/go

  printf "${GREEN}Go ${go_version} installed successfully\n"
}

# Install additional dependencies
install_dependencies() {
  printf "${GREEN}Installing additional dependencies\n"

  # Install protobuf compiler and pkg-config
  if ! command -v protoc &> /dev/null || ! command -v pkg-config &> /dev/null; then
    printf "${GREEN}Installing build dependencies\n"
    if command -v apt-get &> /dev/null; then
      sudo apt-get update
      sudo apt-get install -y protobuf-compiler pkg-config libseccomp-dev
    else
      printf "${YELLOW}Please install protobuf-compiler, pkg-config, and libseccomp-dev manually\n"
    fi
  fi

  # Install Go protobuf plugin
  if ! command -v protoc-gen-go &> /dev/null; then
    printf "${GREEN}Installing Go protobuf plugin\n"
    go install github.com/golang/protobuf/protoc-gen-go@latest
    export PATH=$PATH:$GOPATH/bin
  fi
}

# Check for required dependencies
check_dependencies() {
  local missing_deps=()

  if ! command -v git &> /dev/null; then
    missing_deps+=("git")
  fi

  if ! command -v make &> /dev/null; then
    missing_deps+=("make")
  fi

  if ! command -v gcc &> /dev/null; then
    missing_deps+=("gcc")
  fi

  # Check for Go, install if missing
  if ! command -v go &> /dev/null && [ ! -f /usr/local/go/bin/go ]; then
    printf "${YELLOW}Go not found, installing...\n"
    install_go
  elif [ -f /usr/local/go/bin/go ]; then
    # Go is installed but not in PATH
    export PATH=$PATH:/usr/local/go/bin
    export GOPATH=$HOME/go
  fi

  # Check again after potential installation
  if ! command -v go &> /dev/null; then
    missing_deps+=("go")
  fi

  if [ ${#missing_deps[@]} -ne 0 ]; then
    printf "${RED}Missing required dependencies: %s\n" "${missing_deps[*]}"
    printf "${YELLOW}Please install the missing dependencies and try again.\n"
    printf "${YELLOW}On Ubuntu/Debian: sudo apt-get install git make build-essential\n"
    exit 1
  fi

  # Install additional dependencies
  install_dependencies

  # Display versions for debugging
  printf "${GREEN}Dependencies check passed:\n"
  printf "${GREEN}  Git: $(git --version)\n"
  printf "${GREEN}  Make: $(make --version | head -1)\n"
  printf "${GREEN}  Go: $(go version)\n"
  printf "${GREEN}  GCC: $(gcc --version | head -1)\n"
  if command -v protoc &> /dev/null; then
    printf "${GREEN}  Protoc: $(protoc --version)\n"
  fi
}

if [ -n "$SYSBOX_VERSION" ]; then
  latest_version="$SYSBOX_VERSION"
else
  # Get the latest version from GitHub API
  printf "${GREEN}Checking for latest version from GitHub API\n"
  latest_version=$(curl -s "https://api.github.com/repos/nestybox/sysbox/releases/latest" | jq -r '.tag_name' | sed 's/^v//')
  
  if [ -z "$latest_version" ] || [ "$latest_version" == "null" ]; then
    printf "${YELLOW}Failed to get latest version from GitHub API, falling back to default version\n"
    latest_version="0.6.7"
  fi
fi

printf "${GREEN}Using version %s\n" "$latest_version"

# Check dependencies before proceeding (unless SKIP_DEPS is set)
if [ "${SKIP_DEPS:-false}" != "true" ]; then
  check_dependencies
fi

FORCE=${FORCE:-false}

if [ -d sysbox-"$latest_version" ]; then
  if [ "$FORCE" == "false" ]; then
    printf "${RED}Version already exists\n"
    exit 0
  fi
  printf "${YELLOW}Version exists but FORCE was set, removing existing version\n"
  rm -Rf sysbox-"$latest_version"
fi

mkdir -p sysbox-"$latest_version"
pushd sysbox-"$latest_version" > /dev/null || exit 1
createDirs

# Create additional directories
printf "${GREEN}Creating directories\n"
mkdir -p usr/local/bin
mkdir -p usr/local/lib/systemd/system
mkdir -p usr/local/lib/systemd/system/multi-user.target.d
mkdir -p usr/local/share/doc/sysbox
mkdir -p usr/local/etc/sysctl.d
mkdir -p usr/local/lib/modules-load.d

# Clone and build Sysbox from source
printf "${GREEN}Cloning and building Sysbox\n"

# Set up Go environment
export PATH=$PATH:/usr/local/go/bin
export GOPATH=$HOME/go
export GOCACHE=$HOME/.cache/go-build
mkdir -p "$GOPATH" "$GOCACHE"

# Clone the repository directly into the sysext directory
printf "${GREEN}Cloning Sysbox repository\n"
pushd "$sysext_name" > /dev/null || exit 1
if ! git clone --recursive --branch "v${latest_version}" https://github.com/nestybox/sysbox.git build; then
  printf "${RED}Failed to clone Sysbox repository\n"
  exit 1
fi
cd build || exit 1

# Build Sysbox components using the simple build targets
printf "${GREEN}Building Sysbox components (this may take several minutes)\n"

# Build sysbox-runc first
printf "${GREEN}Building sysbox-runc\n"
if ! make sysbox-runc-static; then
  printf "${RED}Failed to build sysbox-runc\n"
  exit 1
fi

# Build sysbox-fs
printf "${GREEN}Building sysbox-fs\n"
if ! make sysbox-fs-static; then
  printf "${RED}Failed to build sysbox-fs\n"
  exit 1
fi

# Build sysbox-mgr
printf "${GREEN}Building sysbox-mgr\n"
if ! make sysbox-mgr-static; then
  printf "${RED}Failed to build sysbox-mgr\n"
  exit 1
fi

arch="amd64"

if [ "$(uname -m)" = "aarch64" ]; then
  arch="arm64"
fi

# Copy binaries to the system extension directory
printf "${GREEN}Copying binaries to system extension\n"
cp "sysbox-fs/build/${arch}/sysbox-fs" "../usr/local/bin/" || {
  printf "${RED}Failed to copy sysbox-fs binary\n"
  exit 1
}
cp "sysbox-mgr/build/${arch}/sysbox-mgr" "../usr/local/bin/" || {
  printf "${RED}Failed to copy sysbox-mgr binary\n"
  exit 1
}
cp "sysbox-runc/build/${arch}/sysbox-runc" "../usr/local/bin/" || {
  printf "${RED}Failed to copy sysbox-runc binary\n"
  exit 1
}

# Go back to the sysext directory
cd .. || exit 1

# Create the main sysbox wrapper script
cat > "usr/local/bin/sysbox" << 'EOF'
#!/bin/bash
# Sysbox wrapper script
exec /usr/local/bin/sysbox-runc "$@"
EOF
chmod +x "usr/local/bin/sysbox"

# Copy systemd service files
printf "${GREEN}Copying systemd service files\n"
cp build/sysbox-pkgr/systemd/sysbox-fs.service usr/local/lib/systemd/system/
cp build/sysbox-pkgr/systemd/sysbox-mgr.service usr/local/lib/systemd/system/
cp build/sysbox-pkgr/systemd/sysbox.service usr/local/lib/systemd/system/

# Create systemd target configuration to enable the services
cat > "usr/local/lib/systemd/system/multi-user.target.d/10-sysbox-service.conf" << 'EOF'
[Unit]
Wants=sysbox.service
EOF

# Create sysctl configuration for Sysbox
printf "${GREEN}Creating sysctl configuration\n"
cat > "usr/local/etc/sysctl.d/99-sysbox-sysctl.conf" << 'EOF'
# Sysbox sysctl settings

# Enable unprivileged user namespaces
kernel.unprivileged_userns_clone = 1

# Increase the number of user namespaces
user.max_user_namespaces = 65536

# Increase the number of PID namespaces
kernel.pid_max = 4194304

# Enable memory overcommit
vm.overcommit_memory = 1

# Increase the maximum number of memory map areas a process may have
vm.max_map_count = 262144

# Increase the maximum number of open files
fs.file-max = 1048576

# Increase the maximum number of inotify watches
fs.inotify.max_user_watches = 1048576
fs.inotify.max_user_instances = 1024

# Enable IP forwarding
net.ipv4.ip_forward = 1
net.ipv6.conf.all.forwarding = 1

# Enable bridge netfilter
net.bridge.bridge-nf-call-iptables = 1
net.bridge.bridge-nf-call-ip6tables = 1
EOF

# Create modules-load configuration
printf "${GREEN}Creating modules-load configuration\n"
cat > "usr/local/lib/modules-load.d/sysbox.conf" << 'EOF'
# Sysbox required kernel modules
br_netfilter
overlay
EOF

# Copy documentation
printf "${GREEN}Copying documentation\n"
if [ -f "build/README.md" ]; then
  cp "build/README.md" "usr/local/share/doc/sysbox/"
fi

if [ -f "build/LICENSE" ]; then
  cp "build/LICENSE" "usr/local/share/doc/sysbox/"
fi

# Clean up build directory
rm -Rf "build"

# Define service mappings for GitHub Actions workflow
defineServiceMappings "sysbox.service sysbox-fs.service sysbox-mgr.service"

# Create extension release
printf "${GREEN}Creating extension release\n"
createExtensionRelease sysbox-"$latest_version" true
find . -type d -empty -delete
popd > /dev/null || exit 1

if [ "${PUSH}" != false ]; then
  buildAndPush sysbox-"$latest_version"
fi

if [ "${KEEP_FILES}" == "false" ]; then
  rm -Rf sysbox-"$latest_version"
fi

printf "${GREEN}Done\n"
