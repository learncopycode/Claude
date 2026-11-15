#!/usr/bin/env bash
# Creates the Xcode project for the Zikr iPhone app on a Mac (GitHub Actions macOS runner).
# Run from ZikrApp/ios-app. Uses BUNDLE_ID (default com.learncopycode.zikr).
set -euo pipefail
BUNDLE_ID="${BUNDLE_ID:-com.learncopycode.zikr}"
cd "$(dirname "$0")/.."

# the app id goes in before the project is generated
node -e 'const f="capacitor.config.json",fs=require("fs"),c=JSON.parse(fs.readFileSync(f));c.appId=process.argv[1];fs.writeFileSync(f,JSON.stringify(c,null,2))' "$BUNDLE_ID"

npm ci --no-audit --no-fund
npm run www
rm -rf ios
npx cap add ios
npx cap sync ios

APP=ios/App/App
PLIST="$APP/Info.plist"
pb() { /usr/libexec/PlistBuddy -c "$1" "$PLIST" 2>/dev/null || true; }
pb "Delete :CFBundleDisplayName"; pb "Add :CFBundleDisplayName string Zikr"
pb "Delete :NSLocationWhenInUseUsageDescription"
pb "Add :NSLocationWhenInUseUsageDescription string Zikr uses your location only to work out prayer times for where you are. It stays on your phone."
pb "Delete :ITSAppUsesNonExemptEncryption"; pb "Add :ITSAppUsesNonExemptEncryption bool false"
pb "Delete :UISupportedInterfaceOrientations"; pb "Add :UISupportedInterfaceOrientations array"; pb "Add :UISupportedInterfaceOrientations:0 string UIInterfaceOrientationPortrait"
pb "Delete :UISupportedInterfaceOrientations~ipad"

# iPhone only, so no iPad screenshots are needed for the App Store
sed -i '' 's/TARGETED_DEVICE_FAMILY = "1,2";/TARGETED_DEVICE_FAMILY = 1;/g' ios/App/App.xcodeproj/project.pbxproj

# app icon (one 1024 image; Xcode makes the other sizes)
ICON="$APP/Assets.xcassets/AppIcon.appiconset"
rm -rf "$ICON" && mkdir -p "$ICON"
cp resources/AppIcon-1024.png "$ICON/AppIcon-1024.png"
cat > "$ICON/Contents.json" <<'JSON'
{ "images": [ { "filename": "AppIcon-1024.png", "idiom": "universal", "platform": "ios", "size": "1024x1024" } ],
  "info": { "author": "xcode", "version": 1 } }
JSON

# launch screen
SPLASH="$APP/Assets.xcassets/Splash.imageset"
if [ -d "$SPLASH" ]; then
  for f in "$SPLASH"/*.png; do cp resources/Splash-2732.png "$f"; done
fi

# the 30-second adhan for notifications, added to the app bundle
cp resources/adhan.caf "$APP/adhan.caf"
ruby -e '
  begin; require "xcodeproj"; rescue LoadError; Gem.install("xcodeproj"); Gem.refresh; require "xcodeproj"; end
  p = Xcodeproj::Project.open("ios/App/App.xcodeproj")
  t = p.targets.find { |x| x.name == "App" }
  g = p.main_group.find_subpath("App", false)
  unless t.resources_build_phase.files_references.any? { |r| r && r.path == "adhan.caf" }
    t.add_resources([g.new_reference("adhan.caf")])
  end
  p.save
  puts "adhan.caf added to the App target"
'
echo "iOS project ready: $BUNDLE_ID"
