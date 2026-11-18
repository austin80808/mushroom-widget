#!/bin/sh
# Developer ID sign and notarize the cake app and the sibling helper.
# An ad-hoc signature is not acceptance. If the identity or notary credentials
# are missing, this exits non-zero and says why.
set -e
cd "$(dirname "$0")/.."
stage="${1:-build/stage}"
cake="$stage/Mushroom Widget.app"
ears="$stage/MushroomEars.app"
ident="$(security find-identity -v -p codesigning | awk -F'"' '/Developer ID Application/ { print $2; exit }')"
if [ -z "$ident" ]; then
  echo "no Developer ID Application identity in the keychain" >&2
  security find-identity -v -p codesigning >&2 || true
  exit 1
fi
codesign --force --options runtime --timestamp --sign "$ident" "$cake/Contents/MacOS/cake-runtime"
codesign --force --options runtime --timestamp --sign "$ident" "$cake"
codesign --force --options runtime --timestamp --sign "$ident" "$ears"
ditto -c -k --keepParent "$cake" build/cake.zip
ditto -c -k --keepParent "$ears" build/ears.zip
xcrun notarytool submit build/cake.zip --keychain-profile notarytool --wait
xcrun notarytool submit build/ears.zip --keychain-profile notarytool --wait
xcrun stapler staple "$cake"
xcrun stapler staple "$ears"
spctl --assess -vv --type execute "$cake"
spctl --assess -vv --type execute "$ears"
