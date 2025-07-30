#!/bin/bash

# Get the directory where this script is located
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

# Reset git state
git reset --hard HEAD
git clean -fd

cd "$SCRIPT_DIR/bindingTestApp"
rm -rf binding_builder
rm -rf hot_loader

# Download installer from GitHub
echo "Downloading SwiftJsonUI installer..."
cd bindingTestApp
curl -fsSL https://raw.githubusercontent.com/Tai-Kimura/SwiftJsonUI/master/installer/bootstrap.sh | bash -s -- -v 6.1.0 --skip-bundle

cd "$SCRIPT_DIR/bindingTestApp/binding_builder/"
./sjui setup
./sjui g view splash --root
./sjui g partial partial_test
./sjui g partial common/navigation_bar

# Start hot loader listener
echo "Starting hot loader listener..."
./sjui hotload listen &
echo "Hot loader listener started"