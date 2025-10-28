#!/bin/bash
# Copyright 2024 KVCache.AI
#
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

# Color definitions
GREEN="\033[0;32m"
BLUE="\033[0;34m"
YELLOW="\033[0;33m"
RED="\033[0;31m"
NC="\033[0m" # No Color

# Configuration
REPO_ROOT=`pwd`
GITHUB_PROXY=${GITHUB_PROXY:-"https://github.com"}
GOVER=1.23.8

# Function to print section headers
print_section() {
    echo -e "\n${BLUE}=== $1 ===${NC}"
}

# Function to print success messages
print_success() {
    echo -e "${GREEN}✓ $1${NC}"
}

# Function to print error messages and exit
print_error() {
    echo -e "${RED}✗ ERROR: $1${NC}"
    exit 1
}

# Function to print warning messages
print_warning() {
    echo -e "${YELLOW}⚠ $1${NC}"
}

# Function to print info messages
print_info() {
    echo -e "${BLUE}ℹ $1${NC}"
}

# Function to check command success
check_success() {
    if [ $? -ne 0 ]; then
        print_error "$1"
    fi
}

if [ $(id -u) -ne 0 ]; then
	print_error "Require root permission, try sudo ./dependencies.sh"
fi

# Parse command line arguments
SKIP_CONFIRM=false
for arg in "$@"; do
    case $arg in
        -y|--yes)
            SKIP_CONFIRM=true
            ;;
        -h|--help)
            echo -e "${YELLOW}Mooncake Dependencies Installer${NC}"
            echo -e "Usage: ./dependencies.sh [OPTIONS]"
            echo -e "\nOptions:"
            echo -e "  -y, --yes    Skip confirmation and install all dependencies"
            echo -e "  -h, --help   Show this help message and exit"
            exit 0
            ;;
    esac
done

# Print welcome message
echo -e "${YELLOW}Mooncake Dependencies Installer${NC}"
echo -e "This script will install all required dependencies for Mooncake."
echo -e "The following components will be installed:"
echo -e "  - System packages (build tools, libraries)"
echo -e "  - yalantinglibs"
echo -e "  - Go $GOVER"
echo -e "${YELLOW}Note: Git submodules initialization will be skipped as it's already done manually.${NC}"
echo

# Ask for confirmation unless -y flag is used
if [ "$SKIP_CONFIRM" = false ]; then
    read -p "Do you want to continue? [Y/n] " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]] && [[ ! $REPLY = "" ]]; then
        echo -e "${YELLOW}Installation cancelled.${NC}"
        exit 0
    fi
fi

# Update package lists
print_section "Updating package lists"
apt-get update
check_success "Failed to update package lists"

# Install system packages
print_section "Installing system packages"
echo -e "${YELLOW}This may take a few minutes...${NC}"

SYSTEM_PACKAGES="build-essential \
                  cmake \
                  git \
                  wget \
                  libibverbs-dev \
                  libgoogle-glog-dev \
                  libgtest-dev \
                  libjsoncpp-dev \
                  libunwind-dev \
                  libnuma-dev \
                  libpython3-dev \
                  libboost-all-dev \
                  libssl-dev \
                  libgrpc-dev \
                  libgrpc++-dev \
                  libprotobuf-dev \
                  libyaml-cpp-dev \
                  protobuf-compiler-grpc \
                  libcurl4-openssl-dev \
                  libhiredis-dev \
                  pkg-config \
                  patchelf"

apt-get install -y $SYSTEM_PACKAGES
check_success "Failed to install system packages"
print_success "System packages installed successfully"

# Install yalantinglibs
print_section "Installing yalantinglibs"

# Check if thirdparties directory exists
if [ ! -d "${REPO_ROOT}/thirdparties" ]; then
    mkdir -p "${REPO_ROOT}/thirdparties"
    check_success "Failed to create thirdparties directory"
fi

# Change to thirdparties directory
cd "${REPO_ROOT}/thirdparties"
check_success "Failed to change to thirdparties directory"

# Check if yalantinglibs is already manually downloaded
if [ -d "yalantinglibs" ]; then
    print_info "Found manually downloaded yalantinglibs in thirdparties directory."
    print_info "Using existing yalantinglibs for installation."
    
    # Build and install the existing yalantinglibs
    cd yalantinglibs
    check_success "Failed to change to yalantinglibs directory"
    
    # Verify it's the correct version by checking if it's a git repository
    if [ -d ".git" ]; then
        CURRENT_VERSION=$(git describe --tags 2>/dev/null || echo "unknown")
        print_info "Current yalantinglibs version: $CURRENT_VERSION"
    else
        print_info "Using manually prepared yalantinglibs directory."
    fi
else
    print_error "yalantinglibs not found in thirdparties directory."
    print_error "Please manually download yalantinglibs to:"
    print_error "  ${REPO_ROOT}/thirdparties/yalantinglibs"
    print_error "and ensure it's the correct version (0.5.5), then run this script again."
    exit 1
fi

# Build and install yalantinglibs
mkdir -p build
check_success "Failed to create build directory"

cd build
check_success "Failed to change to build directory"

echo "Configuring yalantinglibs..."
cmake .. -DBUILD_EXAMPLES=OFF -DBUILD_BENCHMARK=OFF -DBUILD_UNIT_TESTS=OFF
check_success "Failed to configure yalantinglibs"

echo "Building yalantinglibs (using $(nproc) cores)..."
cmake --build . -j$(nproc)
check_success "Failed to build yalantinglibs"

echo "Installing yalantinglibs..."
cmake --install .
check_success "Failed to install yalantinglibs"

print_success "yalantinglibs installed successfully"

# Skip git submodules initialization
print_section "Git Submodules"
print_info "Skipping git submodules initialization as it's already done manually."

print_section "Installing Go $GOVER"

install_go() {
    ARCH=$(uname -m)
    if [ "$ARCH" = "aarch64" ]; then
        ARCH="arm64"
    elif [ "$ARCH" = "x86_64" ]; then
        ARCH="amd64"
    else
        echo "Unsupported architecture: $ARCH"
        exit 1
    fi
    # Download Go
    echo "Downloading Go $GOVER..."
    wget -q --show-progress https://go.dev/dl/go$GOVER.linux-$ARCH.tar.gz
    check_success "Failed to download Go $GOVER"

    # Install Go
    echo "Installing Go $GOVER..."
    tar -C /usr/local -xzf go$GOVER.linux-$ARCH.tar.gz
    check_success "Failed to install Go $GOVER"

    # Clean up downloaded file
    rm -f go$GOVER.linux-$ARCH.tar.gz
    check_success "Failed to clean up Go installation file"

    print_success "Go $GOVER installed successfully"
}

# Check if Go is already installed
if command -v go &> /dev/null; then
    GO_VERSION=$(go version | awk '{print $3}')
    if [[ "$GO_VERSION" == "go$GOVER" ]]; then
        print_info "Go $GOVER is already installed. Skipping..."
    else
        print_warning "Found Go $GO_VERSION. Will install Go $GOVER..."
        install_go
    fi
else
    install_go
fi

# Add Go to PATH if not already there
if ! grep -q "export PATH=\$PATH:/usr/local/go/bin" ~/.bashrc; then
    echo -e "${YELLOW}Adding Go to your PATH in ~/.bashrc${NC}"
    echo 'export PATH=$PATH:/usr/local/go/bin' >> ~/.bashrc
    echo -e "${YELLOW}Please run 'source ~/.bashrc' or start a new terminal to use Go${NC}"
fi

# Return to the repository root
cd "${REPO_ROOT}"

# Print summary
print_section "Installation Complete"
echo -e "${GREEN}All dependencies have been successfully installed!${NC}"
echo -e "The following components were installed:"
echo -e "  ${GREEN}✓${NC} System packages"
echo -e "  ${GREEN}✓${NC} yalantinglibs"
echo -e "  ${GREEN}✓${NC} Go $GOVER"
echo -e "${YELLOW}Git submodules were skipped (already done manually).${NC}"
echo
echo -e "You can now build and run Mooncake."
echo -e "${YELLOW}Note: You may need to restart your terminal or run 'source ~/.bashrc' to use Go.${NC}"