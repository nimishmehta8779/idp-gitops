#!/bin/bash
set -e

# Colored output utilities
RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0;0m' # No Color

echo "Starting Node.js and Yarn setup..."

# Check if NVM is installed
export NVM_DIR="$HOME/.nvm"
if [ ! -s "$NVM_DIR/nvm.sh" ]; then
    echo "NVM not found. Installing NVM v0.39.7..."
    curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.7/install.sh | bash || true
    if [ ! -s "$NVM_DIR/nvm.sh" ]; then
        echo -e "${RED}✗ NVM installation failed.${NC}"
        exit 1
    fi
else
    echo -e "${GREEN}✓ NVM is already installed.${NC}"
fi

# Load NVM
echo "Loading NVM..."
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"

# Install Node.js 20
echo "Installing Node.js 20.x..."
nvm install 20
nvm use 20
nvm alias default 20

echo -e "${GREEN}✓ Node.js $(node -v) installed and set as default.${NC}"

# Enable corepack and activate yarn 4.x
echo "Enabling Corepack..."
corepack enable

echo "Preparing and activating Yarn v4 (Berry)..."
corepack prepare yarn@4.x --activate

echo -e "${GREEN}✓ Yarn $(yarn -v) activated.${NC}"
echo -e "${GREEN}✓ Node.js and Yarn setup completed successfully!${NC}"
echo "Please reload your shell or run: source ~/.zshrc (or ~/.bash_profile) to apply NVM configuration to your terminal."
