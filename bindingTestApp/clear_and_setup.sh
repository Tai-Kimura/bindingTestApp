#!/bin/bash

# Get the directory where this script is located
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

# Reset git state
git reset --hard HEAD
git clean -fd

cd "$SCRIPT_DIR/bindingTestApp"
rm -rf sjui_tools
cd ..
# Download installer from GitHub
echo "Downloading SwiftJsonUI installer..."
curl -fsSL https://raw.githubusercontent.com/Tai-Kimura/SwiftJsonUI/7.0.0-beta/installer/bootstrap.sh | bash -s -- -v 7.0.0-beta -d ./bindingTestApp

cd "$SCRIPT_DIR/bindingTestApp/"
./sjui_tools/bin/sjui setup
./sjui_tools/bin/sjui g view splash --root
./sjui_tools/bin/sjui g partial partial_test
./sjui_tools/bin/sjui g partial common/navigation_bar
./sjui_tools/bin/sjui g view main
./sjui_tools/bin/sjui g collection Main/ListItem

# Start hot loader listener
echo "Starting hot loader listener..."
./sjui_tools/bin/sjui hotload listen &
echo "Hot loader listener started"