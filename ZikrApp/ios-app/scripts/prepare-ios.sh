#!/usr/bin/env bash
# Creates the Xcode project for the Zikr iPhone app on a Mac (GitHub Actions macOS runner).
# Run from ZikrApp/ios-app. Uses BUNDLE_ID (default com.learncopycode.zikr).
# WITH_ALARMS=0 builds without the AlarmKit plugin (the full-adhan alarm); the app then uses notifications.
set -euo pipefail
BUNDLE_ID="${BUNDLE_ID:-com.learncopycode.zikr}"
WITH_ALARMS="${WITH_ALARMS:-1}"
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
pb "Delete :NSAlarmKitUsageDescription"
pb "Add :NSAlarmKitUsageDescription string Zikr sets an alarm at each prayer time so the full adhan plays, even when the app is closed."
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

# adhan sounds in the app bundle: 30 s for notifications, the full adhan for alarms
cp resources/adhan.caf resources/adhan_full.caf "$APP/"
if [ "$WITH_ALARMS" = "1" ]; then cp native/AdhanAlarmPlugin.swift "$APP/AdhanAlarmPlugin.swift"; fi
WITH_ALARMS="$WITH_ALARMS" ruby -e '
  begin; require "xcodeproj"; rescue LoadError; Gem.install("xcodeproj"); Gem.refresh; require "xcodeproj"; end
  p = Xcodeproj::Project.open("ios/App/App.xcodeproj")
  t = p.targets.find { |x| x.name == "App" }
  g = p.main_group.find_subpath("App", false)
  have = ->(phase, name) { phase.files_references.any? { |r| r && r.path == name } }
  %w[adhan.caf adhan_full.caf].each { |f| t.add_resources([g.new_reference(f)]) unless have.(t.resources_build_phase, f) }
  if ENV["WITH_ALARMS"] == "1" && !have.(t.source_build_phase, "AdhanAlarmPlugin.swift")
    t.add_file_references([g.new_reference("AdhanAlarmPlugin.swift")])
  end
  p.save
  puts "sounds added; alarm plugin: #{ENV["WITH_ALARMS"] == "1" ? "yes" : "no"}"
'
# register the plugin with Capacitor (it loads plugins by class name from this list)
if [ "$WITH_ALARMS" = "1" ]; then
  node -e 'const f=process.argv[1],fs=require("fs"),c=JSON.parse(fs.readFileSync(f));c.packageClassList=[...new Set([...(c.packageClassList||[]),"AdhanAlarmPlugin"])];fs.writeFileSync(f,JSON.stringify(c,null,2))' "$APP/capacitor.config.json"
fi
echo "iOS project ready: $BUNDLE_ID"
