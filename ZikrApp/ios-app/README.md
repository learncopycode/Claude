# Zikr for iPhone (no Mac needed)

The iPhone app is the same app as `zikr/` in a native shell (Capacitor 8), plus adhan
notifications that sound even when the app is closed (iOS plays up to 30 seconds; tapping the
notification opens the app and plays the full adhan). GitHub's Mac computers build it and send
it to TestFlight; everything below can be done from a phone browser.

## One-time setup

1. **Apple Developer Program** – enrol at developer.apple.com/programs ($99/year). Note your
   **Team ID** (Membership details).
2. **Register the app id** – developer.apple.com → Certificates, IDs & Profiles → Identifiers → +
   → App IDs → App → Bundle ID `com.learncopycode.zikr` (or your own; then set it as the repository
   variable `BUNDLE_ID`). No extra capabilities are needed (the adhan uses local notifications).
3. **Create the app** – appstoreconnect.apple.com → Apps → + → New App: platform iOS, name "Zikr"
   (or another free name), the bundle id above, SKU e.g. `zikr`.
4. **API key** – App Store Connect → Users and Access → Integrations → App Store Connect API →
   Team Keys → + : name "GitHub", access **Admin**. Note the **Key ID** and the **Issuer ID**, and
   download the `.p8` file once (open it and copy all its text).
5. **GitHub secrets** – github.com/learncopycode/Claude → Settings → Secrets and variables →
   Actions → New repository secret, four times:
   - `APPSTORE_KEY_ID` – the Key ID
   - `APPSTORE_ISSUER_ID` – the Issuer ID
   - `APPSTORE_KEY_P8` – the whole text of the .p8 file, including the BEGIN/END lines
   - `APPLE_TEAM_ID` – the Team ID

## Build

Any push that changes `zikr/` or this folder builds and uploads a new version. To build without a
change: Actions → "iPhone app → TestFlight" → Run workflow (the button appears once this file is on
the default branch), or re-run the last run.

After 10–30 minutes the build appears in App Store Connect → TestFlight. Install the **TestFlight**
app on your iPhone and add yourself as an internal tester to install Zikr.

## Publish on the App Store

App Store Connect → the app → fill in the description, keywords, support URL, a privacy policy URL
(`https://learncopycode.github.io/Claude/zikr/privacy.html` once GitHub Pages is on), screenshots
(6.9" iPhone; take them on your phone), age rating, and "App Privacy: Data Not Collected". Choose
the build and Submit for Review.

## Files

- `capacitor.config.json` – app id, name, colours
- `resources/AppIcon-1024.png`, `resources/Splash-2732.png` – icon and launch screen
- `resources/adhan.caf` – the first 29.5 s of the adhan (CC0 recording, faded out) for notifications
- `scripts/prepare-ios.sh` – makes the Xcode project on the Mac runner (icon, launch screen,
  location text, iPhone-only, adhan sound)
- `../../.github/workflows/ios-testflight.yml` – builds, signs (automatic signing with the API key)
  and uploads
