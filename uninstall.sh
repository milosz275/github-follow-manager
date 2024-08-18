#!/bin/bash

INSTALL_DIR="/usr/local/bin"
UTILITY_NAME="github-follow-manager"

if [ "$EUID" -ne 0 ]; then
    echo "Please run as root or with sudo"
    exit 1
fi

echo "Are you sure you want to uninstall $UTILITY_NAME? (y/n)"
read -r confirm
if [ "$confirm" != "y" ]; then
    echo "Uninstallation aborted."
    exit 0
fi

if [ -f "$INSTALL_DIR/$UTILITY_NAME" ]; then
    echo "Removing $INSTALL_DIR/$UTILITY_NAME..."
    sudo rm -f "$INSTALL_DIR/$UTILITY_NAME"
else
    echo "$UTILITY_NAME not found in $INSTALL_DIR."
    exit 1
fi

echo "$UTILITY_NAME has been uninstalled successfully."
exit 0
