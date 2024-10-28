#!/bin/bash

set -e

INSTALL_DIR="/usr/local/bin"
SCRIPT_NAME="follow_manager.sh"
UTILITY_NAME="github-follow-manager"

if [ "$EUID" -ne 0 ]; then
    echo "Please run as root or with sudo"
    exit 1
fi

echo "Downloading $UTILITY_NAME..."
curl -L https://github.com/milosz275/github-follow-manager/raw/main/$SCRIPT_NAME -o $INSTALL_DIR/$UTILITY_NAME

echo "Making $UTILITY_NAME executable..."
chmod +x $INSTALL_DIR/$UTILITY_NAME

echo "$UTILITY_NAME has been installed in $INSTALL_DIR"
echo "Please run '$UTILITY_NAME' to complete the setup."
