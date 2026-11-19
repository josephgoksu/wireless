#!/bin/zsh
# Build a Developer ID signed, notarized Wireless.dmg and (with PUBLISH=1) attach it to a GitHub release.
#   NOTARY_PROFILE=<keychain profile> PUBLISH=1 make release
# Without NOTARY_PROFILE you get a signed DMG that Gatekeeper will still warn about.
set -euo pipefail
cd "${0:A:h}/.."

VERSION=$(sed -n 's/.*MARKETING_VERSION: "\(.*\)"/\1/p' project.yml)
IDENTITY=${DEVELOPER_ID:-$(security find-identity -v -p codesigning | awk -F'"' '/Developer ID Application/ {print $2; exit}')}
TEAM=$(sed -n 's/.*(\([A-Z0-9]*\))$/\1/p' <<< "$IDENTITY")
OUT=build/release
APP=$OUT/Build/Products/Release/Wireless.app
DMG=$OUT/Wireless.dmg
[[ -n "$TEAM" ]] || { echo "No Developer ID Application identity in the keychain."; exit 1; }

echo "==> Build $VERSION, signed by $IDENTITY"
rm -rf $OUT && xcodegen --quiet
xcodebuild -project Wireless.xcodeproj -scheme Wireless -configuration Release -derivedDataPath $OUT -quiet build \
  DEVELOPMENT_TEAM=$TEAM CODE_SIGN_STYLE=Manual CODE_SIGN_IDENTITY="$IDENTITY" OTHER_CODE_SIGN_FLAGS=--timestamp \
  CODE_SIGN_INJECT_BASE_ENTITLEMENTS=NO ARCHS="arm64 x86_64" ONLY_ACTIVE_ARCH=NO
codesign --verify --deep --strict $APP
for bin in $APP $APP/Contents/PlugIns/WirelessWidget.appex; do   # notarization rejects the debugger entitlement
  ! codesign -d --entitlements - $bin 2>/dev/null | grep -q get-task-allow || { echo "get-task-allow in $bin"; exit 1; }
done
lipo -archs $APP/Contents/MacOS/Wireless

echo "==> Disk image"
mkdir -p $OUT/dmg && cp -R $APP $OUT/dmg/ && ln -s /Applications $OUT/dmg/Applications
hdiutil create -quiet -volname Wireless -srcfolder $OUT/dmg -format UDZO -ov $DMG
codesign --sign "$IDENTITY" --timestamp $DMG

if [[ -n "${NOTARY_PROFILE:-}" ]]; then
  echo "==> Notarize"
  xcrun notarytool submit $DMG --keychain-profile "$NOTARY_PROFILE" --wait
  xcrun stapler staple $DMG
  spctl --assess --type open --context context:primary-signature -v $DMG
else
  echo "NOTARY_PROFILE not set: signed but not notarized."
fi
shasum -a 256 $DMG

if [[ -n "${PUBLISH:-}" ]]; then
  echo "==> GitHub release v$VERSION"
  gh release create "v$VERSION" $DMG --title "Wireless $VERSION" --notes-file - <<EOF
Open **Wireless.dmg**, drag Wireless to Applications, and launch it. Then add the widget: right-click the desktop → Edit Widgets → Wireless.

macOS 15 or later · Apple silicon and Intel · signed and notarized.
EOF
fi
