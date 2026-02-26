#!/bin/sh

set -eu

rm -rf dist/Reynard
mkdir -p dist/Reynard

cp -R dist/Reynard.xcarchive/Products/Applications dist/Reynard/Payload

cd dist/Reynard
zip -r ../Reynard.ipa . -x "._*" -x ".DS_Store" -x "__MACOSX"
