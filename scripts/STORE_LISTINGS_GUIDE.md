# Store listings guide (App Store + Google Play)

How the 1-2-1 Connect listings were made: screenshots, feature graphic, icon,
text, and the upload to both stores. Written for another Claude session to
follow on a different Flutter app. Working examples are in this repo; copy them
and change the content.

The approach in one line: **render the real app screens in a Flutter widget test
with fake data, frame them with a Python script, keep all listing text in
fastlane's metadata folders, and push with fastlane using API keys.** No
simulator screenshots, no manual uploads, no design tool.

---

## 0. Before you start (ask the user once)

- App name, one-line subtitle, and 6 to 8 features to show (one per screenshot).
- Brand colours and the app's font file (TTF).
- Store access:
  - **Apple:** App Store Connect API key (`.p8`, key id, issuer id) with App
    Manager role. Keep it outside the repo, e.g. `~/.app-secrets/`.
  - **Google:** Play service-account JSON with release + listing permissions.
    Also outside the repo.
- Privacy, support and marketing URLs (must exist and load before review).
- A demo account for Apple review (login + password) if the app needs sign-in.

Never commit keys. Never put real people in screenshots: use fictional names.

---

## 1. Raw screens: a widget test that renders the real UI

Example: `test/store/store_screens_test.dart`.

1. Create one `testWidgets` per screen. Pump the real screen widget inside
   `ProviderScope` (or your state setup) with **overrides that return fake
   data**: fictional members, a believable conclave, numbers that look alive.
   Fake any service that would hit the network (sync, auth, repositories).
2. Size the test view to the largest store size, at 3x:
   ```dart
   tester.view.physicalSize = const Size(1320, 2868); // iPhone 6.9"
   tester.view.devicePixelRatio = 3;
   tester.view.padding = const FakeViewPadding(top: 62 * 3, bottom: 34 * 3);
   addTearDown(tester.view.reset);
   ```
3. **Load real fonts**, or text renders as boxes:
   ```dart
   final l = FontLoader('YourFont')
     ..addFont(Future.value(ByteData.sublistView(File('assets/fonts/YourFont.ttf').readAsBytesSync())));
   await l.load();
   ```
   Load the icon font the same way.
4. Precache image assets inside `tester.runAsync(...)`, then pump in small steps
   (e.g. 12 x 250 ms) so animations settle. Avoid `pumpAndSettle` on screens
   with endless animations.
5. Save each screen as a golden into a raw folder:
   ```dart
   await expectLater(find.byType(MaterialApp), matchesGoldenFile('../../store/raw/$name.png'));
   ```
6. Run: `flutter test test/store/store_screens_test.dart --update-goldens`
7. **Look at every PNG** (open it) before going on: overflow stripes, empty
   states, debug banners (`debugShowCheckedModeBanner: false`), wrong dates.

Pitfall: if a screen reads Firebase or config at build time, inject fakes;
widget tests have no Firebase.

---

## 2. Frame them: headline + device frame per store size

Example: `tool/store/frame.py` (Python + Pillow). Run `python tool/store/frame.py`.

For each raw screen it draws:
- a brand gradient background,
- a short **headline** (2 lines max) and one supporting line, in the app font,
- the screen scaled down inside a rounded "phone" body with a soft shadow,
  bleeding off the bottom edge.

The `SHOTS` list sets order and copy. Put the strongest feature first; stores
show the first 2 or 3 in search.

Outputs (exact pixel sizes matter, the stores reject others):

| Target | Size (px) | Folder |
|---|---|---|
| App Store iPhone 6.9" | 1320 x 2868 | `store/appstore/6.9in/` |
| App Store iPhone 6.5" | 1284 x 2778 | `store/appstore/6.5in/` |
| Google Play phone | 1080 x 1920 | `store/playstore/phone/` |
| Play feature graphic | 1024 x 500 | `store/playstore/feature_graphic.png` |
| Play icon | 512 x 512 | `store/playstore/icon_512.png` |

Rules that caused rejections or warnings:
- **Save as RGB, no alpha channel.** Apple rejects screenshots with
  transparency. Convert with `.convert("RGB")` before saving.
- Same pixel size for every screenshot in one set.
- No "Download now", prices, ratings or other apps' marks in the images.
- Never stretch to fit a size: pad or re-render.

Then copy the framed files into fastlane's folders (step 3).

---

## 3. Listing text and images in fastlane folders

**iOS** (`ios/fastlane/`):
```
metadata/
  copyright.txt  primary_category.txt  secondary_category.txt
  en-US/ name.txt subtitle.txt description.txt keywords.txt
         promotional_text.txt release_notes.txt
         privacy_url.txt support_url.txt marketing_url.txt
  review_information/ demo_user.txt demo_password.txt notes.txt
                      first_name.txt last_name.txt email_address.txt phone_number.txt
screenshots/en-US/ 01_xxx.png ... (the 6.9" set; Apple scales for smaller phones)
```
Limits: name 30, subtitle 30, keywords 100 (comma-separated, no spaces), promo
text 170, description 4000 characters.

**Android** (`android/fastlane/metadata/android/en-US/`):
```
title.txt                (30)
short_description.txt    (80)
full_description.txt     (4000)
changelogs/<versionCode>.txt   (500)
images/icon.png                 512x512
images/featureGraphic.png       1024x500
images/phoneScreenshots/1_en-US.png ... (2 to 8)
```

Write the text once from the same facts (see `tool/brand/copy.md` for the
house style): plain, specific, what the app does in the room, no hype, no
emojis. Keep brand names of third parties (e.g. BNI) as "for X", not as if
official.

---

## 4. Push to the stores

**Apple** (lane `push_metadata` in `ios/fastlane/Fastfile`):
```ruby
lane :push_metadata do |options|
  deliver(
    api_key: app_store_connect_api_key(key_id: KEY_ID, issuer_id: ISSUER, key_filepath: KEY_PATH),
    app_identifier: APP_ID,
    app_version: "x.y.z",          # the version being prepared
    skip_binary_upload: true,
    skip_screenshots: options[:screenshots] != true,
    overwrite_screenshots: options[:screenshots] == true,
    run_precheck_before_submit: false,
    submit_for_review: false,
    force: true,                   # no interactive HTML preview
  )
end
```
Run `fastlane ios push_metadata screenshots:true` the first time, and later
without `screenshots:true` (text only, much faster).

Things only the **App Store Connect website** can do (tell the user, don't
guess): App Privacy questionnaire, Age Rating, Price (Free), content rights.
Submission fails until these are done.

**Google Play** (metadata only, no binary):
```
cd android
fastlane run upload_to_play_store package_name:<pkg> \
  json_key:"$HOME/.app-secrets/play-service-account.json" \
  skip_upload_aab:true skip_upload_apk:true skip_upload_changelogs:true \
  skip_upload_metadata:false skip_upload_images:false skip_upload_screenshots:false
```
If managed publishing is on, listing changes wait for the user to press
Publish in Play Console. The Data safety form, content rating and target
audience are also website-only.

Keep the normal release lane separate and have it **skip** metadata, so a
binary upload never overwrites the listing by accident.

---

## 5. Order of work and checks

1. Render raw screens and look at all of them.
2. Frame and look at all of them at full size.
3. Write the text; check every character limit (`wc -m`).
4. Push iOS metadata with screenshots; push Play listing.
5. Open both consoles (or ask the user to) and confirm the screenshots and
   text show for the right version.
6. Commit the raw screens, framed screens, metadata and scripts, so the next
   release can regenerate everything with two commands.

---

## Traps we hit (and the fix)

- **Text renders as boxes / icons missing:** fonts not loaded in the test.
- **Apple "invalid screenshot":** alpha channel or wrong size. RGB, exact size.
- **ITMS-90853 Invalid Binary** after a custom icon font: the generated TTF
  lacked a full name table (IDs 0 to 6). Write all name records when you build
  a font.
- **ITMS-90473** with a widget extension: its version must follow the app's
  (read from Flutter's `Generated.xcconfig`), not be hard-coded.
- **Fastlane's bundled Ruby breaks CocoaPods:** build the app in a normal shell
  (`flutter build ipa`), then upload with fastlane.
- **Builds with a beta Xcode are rejected** by Apple. Use the release Xcode
  (`DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer`).
- **Screenshots overwritten** when only text should change: keep
  `skip_screenshots` on by default.
- **Play release overwrote the listing:** the release lane must set
  `skip_upload_metadata/images/screenshots: true`.
