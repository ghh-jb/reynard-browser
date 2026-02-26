#!/bin/sh

set -eu

rm -rf dist
rm -f truefox/.mozconfig

echo "ac_add_options --enable-application=mobile/ios" > truefox/.mozconfig
echo "ac_add_options --target=aarch64-apple-ios" >> truefox/.mozconfig
echo "ac_add_options --enable-ios-target=15.0" >> truefox/.mozconfig
echo "ac_add_options --enable-optimize" >> truefox/.mozconfig
echo "ac_add_options --disable-debug" >> truefox/.mozconfig

rustup target list | grep "aarch64-apple-ios (installed)" || rustup target add aarch64-apple-ios

./truefox/mach build

xcodebuild clean -scheme "Reynard" -project "Reynard.xcodeproj" -sdk iphoneos -arch arm64 -configuration Release

xcodebuild archive -scheme "Reynard" -archivePath "dist/Reynard.xcarchive" -project "Reynard.xcodeproj" -sdk iphoneos -arch arm64 -configuration Release -xcconfig "Configuration/Reynard.xcconfig"
