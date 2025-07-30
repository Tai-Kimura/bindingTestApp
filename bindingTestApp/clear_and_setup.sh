#!/bin/bash

# Reset git state
git reset --hard HEAD
git clean -fd

# Clear SPM cache
rm -rf ~/Library/Caches/org.swift.swiftpm
rm -rf ~/Library/Developer/Xcode/DerivedData
rm -rf .build

cd ~/resource/bindingTestApp/bindingTestApp/bindingTestApp
cp -r ~/resource/SwiftJsonUI/installer .
cd installer
./install_sjui.sh -v 6.1.0-alpha --skip-bundle
cd ../binding_builder/
./sjui setup
./sjui g view splash --root
./sjui g partial partial_test
./sjui g partial common/navigation_bar