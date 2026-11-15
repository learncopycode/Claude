#!/usr/bin/env bash
# Archives the app, signs it automatically with the App Store Connect API key and uploads it.
# Needs KEY_ID, ISSUER, P8, TEAM, BUILD_NUMBER. Run from ZikrApp/ios-app after prepare-ios.sh.
set -euo pipefail
VERSION=$(node -p 'require("./package.json").appVersion')
KEY="$RUNNER_TEMP/AuthKey_$KEY_ID.p8"; printf '%s\n' "$P8" > "$KEY"
AUTH=(-allowProvisioningUpdates -authenticationKeyPath "$KEY" -authenticationKeyID "$KEY_ID" -authenticationKeyIssuerID "$ISSUER")
archive() {
  ( cd ios/App
    if [ -d App.xcworkspace ]; then SRC=(-workspace App.xcworkspace); else SRC=(-project App.xcodeproj); fi
    xcodebuild "${SRC[@]}" -scheme App -configuration Release -destination "generic/platform=iOS" \
      -archivePath "$RUNNER_TEMP/Zikr.xcarchive" archive "${AUTH[@]}" \
      DEVELOPMENT_TEAM="$TEAM" CODE_SIGN_STYLE=Automatic \
      MARKETING_VERSION="$VERSION" CURRENT_PROJECT_VERSION="$BUILD_NUMBER" )
}
if ! archive; then
  echo "::warning title=Built without the full-adhan alarm::The AlarmKit plugin did not compile with this Xcode; building again without it (the app uses 30-second adhan notifications instead)."
  WITH_ALARMS=0 ./scripts/prepare-ios.sh
  archive
fi
cat > "$RUNNER_TEMP/ExportOptions.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>method</key><string>app-store-connect</string>
  <key>destination</key><string>upload</string>
  <key>teamID</key><string>$TEAM</string>
  <key>signingStyle</key><string>automatic</string>
  <key>uploadSymbols</key><true/>
</dict></plist>
PLIST
xcodebuild -exportArchive -archivePath "$RUNNER_TEMP/Zikr.xcarchive" \
  -exportOptionsPlist "$RUNNER_TEMP/ExportOptions.plist" -exportPath "$RUNNER_TEMP/export" "${AUTH[@]}"
rm -f "$KEY"
echo "::notice title=Uploaded Zikr $VERSION ($BUILD_NUMBER)::It shows in App Store Connect → TestFlight after Apple processes it (about 10–30 minutes)."
