#!/bin/bash

# Reset git state
git reset --hard HEAD
git clean -fd

# Clear SPM cache
rm -rf ~/Library/Caches/org.swift.swiftpm
rm -rf ~/Library/Developer/Xcode/DerivedData
rm -rf .build

cd ~/resource/bindingTestApp/bindingTestApp/bindingTestApp
rm -rf binding_builder
rm -rf hot_loader
cp -r ~/resource/SwiftJsonUI/installer .
cd installer
./install_sjui.sh --version 6.1.0 --skip-bundle

# Create SPM directory structure to prevent Xcode error
cd ~/resource/bindingTestApp/bindingTestApp
mkdir -p bindingTestApp.xcodeproj/project.xcworkspace/xcshareddata/swiftpm
echo '{
  "pins" : [
  ],
  "version" : 2
}' > bindingTestApp.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved

cd ~/resource/bindingTestApp/bindingTestApp/bindingTestApp/binding_builder/
./sjui setup
./sjui g view splash --root
./sjui g partial partial_test
./sjui g partial common/navigation_bar