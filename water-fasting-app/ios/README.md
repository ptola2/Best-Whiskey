# Waterline for iPhone

Native SwiftUI version of the Waterline water fasting app. Same features and the same research rules as the web version in `../index.html`, built to the iOS App Builder standard: iOS 17, `@Observable` singletons on the main actor, an `AppScreen` enum with a ZStack for the top-level flow, iPhone only.

## Put it in your folder

In Terminal on your Mac:

```sh
mkdir -p ~/Documents/final-apps
cd ~/Documents/final-apps
git clone --depth 1 -b claude/confident-knuth-tttzqq https://github.com/ptola2/Best-Whiskey.git waterline-tmp
mkdir -p "Water fasting"
cp -R waterline-tmp/water-fasting-app/ios/. "Water fasting/"
rm -rf waterline-tmp
open "Water fasting/WaterFasting.xcodeproj"
```

## Run it

1. Needs Xcode 16 or later. The project uses folder-synced groups, so any file you add to `WaterFasting/` is picked up automatically.
2. Select the **WaterFasting** target, then **Signing & Capabilities**, and pick your team. Change the bundle ID (`com.malebolabs.waterline`) if you want a different one.
3. Choose an iPhone simulator and press Run.

No packages, keys or accounts are needed for the app to build and run. Data is saved in a protected file on the device.

## What is inside

```
WaterFasting/
  WaterFastingApp.swift          App entry point (configures Firebase only if present)
  Models/
    Models.swift                 AppData, ActiveFast, CheckIn, RefeedState, PastFast
    Research.swift               Phases, risk windows, symptoms, safety questions, studies, sources
    Logic.swift                  Formatting, safety screen, check-in grading, refeeding planner
    SyncMerge.swift              Combines two copies of the data when devices sync
    L10n.swift                   tr() and trCount(), which look up translated text
    AppLinks.swift               Privacy policy address
    AppLanguage.swift            Language choice, suggestions and flags
  Services/
    FastStore.swift              Single source of truth, JSON cache, all actions
    NotificationService.swift    Milestone alerts and 9:00 / 21:00 check-in reminders
    CloudSync.swift              Optional Firestore backup with Sign in with Apple
    HealthService.swift          Apple Health: reads and saves weight and blood pressure
    WidgetBridge.swift           Keeps the widget and the Live Activity in step with the fast
  Views/
    RootView.swift               Language, welcome and tab bar
    TodayView.swift              Timer, phase timeline, water, warnings, fast planner
    LogView.swift                Check-in form, graded results, weight, history
    RefeedView.swift             Active refeeding plan and standalone planner
    LearnView.swift              The research, section by section, with sources
    ProfileView.swift            Details, safety check, clinician, reminders, data
    CloudCard.swift              Backup and sync card (only with Firebase)
    LanguageViews.swift          Language screen, list with flags, Profile card
    Theme.swift, Components.swift
  Assets.xcassets                App icon and accent colour
  Localizable.xcstrings          All text in 21 languages (generated, see Languages)
  PrivacyInfo.xcprivacy          Privacy manifest required by the App Store
Shared/                          Compiled into both the app and the widget
  FastWidgetData.swift           The fast as the widget sees it, shared through the App Group
  FastActivityAttributes.swift   The Live Activity's data
WaterlineWidget/                 The widget extension
  FastTimerWidget.swift          Home Screen and Lock Screen widgets
  FastLiveActivity.swift         Lock Screen and Dynamic Island Live Activity
Localization/
  en.json, fr.json, ...          Text for each language, edited by hand
  build_catalog.py               Checks the files and writes Localizable.xcstrings
  TRANSLATOR_NOTES.md            Rules and context for translators
```

## Safety rules

Taken from the source document and shared with the web app:

- Any absolute contraindication (type 1 diabetes, pregnancy or breastfeeding, eating disorder, CKD 3b to 5, decompensated cirrhosis, acute porphyria, cachexia, BMI under 18.5, under 18) blocks starting a fast.
- Diuretics and type 2 diabetes medicines need confirmed clinical supervision for any fast. Other relative contraindications need the doctor-reviewed confirmation. Osteopenia or osteoporosis caps fasts at 72 hours.
- Every fast over 72 hours needs confirmed clinical supervision.
- Check-ins flag the warning signs, likely low sodium, an orthostatic drop of 20/10 mmHg or more, a standing pulse rise of 30 or more, water outside 1.2 to 2.5 L, and BHB above 7.0 mmol/L.
- Refeeding lasts at least half the fast and uses the ASPEN and NICE risk tiers.

## Widget and Live Activity

The `WaterlineWidget` extension adds:

- **A Home Screen widget** (small and medium) and **Lock Screen widgets** (circular, rectangular, inline). They show the time fasted so far, counting every second, the current metabolic phase, the next one, and a bar filling toward the target. The widget moves to each new phase by itself, even if the app stays closed.
- **A Live Activity** on the Lock Screen and in the Dynamic Island while a fast runs, with the same live timer and progress bar. iOS ends a Live Activity after about 8 hours, so Waterline starts a fresh one each time the app is opened during a long fast; the widget covers the time in between. People can turn Live Activities off in Settings, Waterline.

The app writes the fast and every label into the shared App Group (`group.com.malebolabs.waterline`) whenever the fast or the language changes, so the widget always matches the language chosen inside Waterline. Only the widget gallery's name and description come from the extension's own catalog (`WaterlineWidget/Localizable.xcstrings`, built by `build_catalog.py` from the `extension.*` keys).

In Xcode, the project now has two targets: **WaterFasting** (the app) and **WaterlineWidgetExtension**. Pick your Team in Signing & Capabilities for both. Each lists App Groups with `group.com.malebolabs.waterline` ticked; with automatic signing Xcode registers the group and the widget's bundle ID (`com.malebolabs.waterline.widget`) for you.

To try it in the simulator: start a fast, go to the Home Screen, long-press, tap Edit, then Add Widget, and pick Waterline. Lock the simulator (Cmd+L) to see the Live Activity.

## Apple Health

Profile has an **Apple Health** switch. Waterline asks for permission only when it is turned on.

- **Check-ins save to Health.** The weight and the lying and standing blood pressure from each check-in are saved to Apple Health. Each blood pressure reading carries its position (`WaterlinePosition` metadata: lying or standing).
- **Health fills in check-ins.** The check-in form shows weight and blood pressure from the last 24 hours that came from other apps or devices (a smart scale, a blood pressure cuff), each with a Use button. Blood pressure can go into the lying or standing fields, and the pulse fills in too when the cuff recorded one at the same time. Profile offers the latest weight from Health for your profile.
- **No duplicates.** Values taken from Health are never written back, and Waterline never offers back what it saved itself.
- **Removing a check-in** removes what Waterline saved to Health for it. "Delete all my data" leaves Health alone; people manage Health data in the Health app.
- Health data stays on the iPhone. It is read and written by `Services/HealthService.swift` only.

Set up, already done in the project: the HealthKit entitlement (`WaterFasting.entitlements`), the two permission texts (`NSHealthShareUsageDescription`, `NSHealthUpdateUsageDescription`, translated in `WaterFasting/InfoPlist.xcstrings`), and the Apple Health section in `PRIVACY_POLICY.md`. Health only works on a real iPhone or a simulator with the Health app; the card is hidden where Health is not available.

**Update the published privacy policy** at malebolabs.com with the new Apple Health part of section 2 before submitting: App Review checks that a HealthKit app's policy describes its Health use.

## Turn on cloud backup (optional)

Your iOS App Builder rules say user data should live in Firestore, with the local file as the offline cache. The code for that is already written in `CloudSync.swift` and `CloudCard.swift`. It switches on by itself once Firebase is added:

1. Firebase console: create a project, add an iOS app with the same bundle ID, download `GoogleService-Info.plist` and drag it into the `WaterFasting` folder in Xcode.
2. Authentication, then Sign-in method: enable **Apple**. Fill in its OAuth code flow section (Apple Team ID, Key ID and private key). Account deletion uses it to revoke the Apple token, which App Review requires.
3. Firestore Database: create it (Standard edition, Production mode) and publish the rules in `firestore.rules`.
4. Xcode: File, then Add Package Dependencies, `https://github.com/firebase/firebase-ios-sdk`. Add **FirebaseAuth** and **FirebaseFirestore** to the WaterFasting target.
5. Signing & Capabilities: add **Sign in with Apple**.

Profile then shows a Backup and sync card. Sign-in is optional and the app keeps working without it. Data is stored at `users/{uid}/waterline/state`.

How the sync behaves:

- Every cloud write carries a server revision number and only lands if nothing changed on the server since this iPhone last synced, so device clocks never decide which copy wins. When two devices both changed, their data is merged (check-ins, past fasts and water are combined; removed check-ins stay removed).
- A cloud copy written by a newer app version is never overwritten; sync pauses and asks for an update.
- **Delete all my data** writes the deletion to the cloud first, so every signed-in device clears too. If that write fails, nothing is deleted.
- **Sign out** backs up anything pending, then removes the data from this iPhone. It stays in the account, and it can never be uploaded into a different account.
- **Delete account** asks for a fresh Sign in with Apple confirmation, revokes the Apple token, deletes the cloud copy and then the account. Data on the iPhone stays.

## Privacy policy

`PRIVACY_POLICY.md` is the app's privacy policy, written to match what the code actually does. It is published at:

**https://malebolabs.com/waterline-privacy-policy/**

1. The app already opens that address from the Welcome screen and from Profile, then Your data (`WaterFasting/Models/AppLinks.swift`), as guideline 5.1.1 requires.
2. In App Store Connect, paste the same address into App Information, then Privacy Policy URL. If you add a Support or Marketing URL, keep them on malebolabs.com too.
3. Keep the page and `PRIVACY_POLICY.md` in step: when one changes, update the other and its "Last updated" date.
4. If version 1 ships without cloud backup, delete section 4, section 11 and the Google Firebase row in section 7, and remove the "Account" row from the table in section 1.

## Languages

The app is translated into 21 languages: English (the source), Arabic, Chinese (Simplified, for Mandarin), Dutch, French, German, Hindi, Indonesian, Italian, Japanese, Korean, Malay, Polish, Portuguese (Brazil), Russian, Spanish, Swahili, Swedish, Thai, Turkish and Vietnamese.

Choosing a language:

- **First launch** opens on a language screen, before the welcome. Each language shows its flag, its own name (Français, العربية) and its name in the language on screen. Tapping one switches the screen at once, so people see the app in that language before they continue.
- **The starting choice** comes from the iPhone. Its language wins when Waterline has it. When the iPhone is in English, which is often just the default, the iPhone's Region decides instead: an English-language iPhone set to France starts in French, one set to Saudi Arabia starts in Arabic, and English stays one tap away under "Suggested for you". Region comes from Settings, not GPS, so there is no location permission and nothing leaves the phone.
- **Flags** follow the person's country where the language is spoken there (Spanish shows Mexico's flag in Mexico, Arabic shows Morocco's in Morocco), otherwise a usual flag for the language.
- **Changing it later:** Profile has a Language card, and the welcome screen has a flag button at the top. Both open the same list, which also offers "Same as iPhone" to follow the phone's settings again (including the per-app language in Settings, then Waterline, then Language).
- The switch is instant, with no restart: every screen, number, date and scheduled reminder changes language. Saved check-in results are shown in the new language too.
- The choice is a setting on the phone (`AppLanguage.swift`, kept in UserDefaults). It is not synced and stays after "Delete all my data".

How it fits together:

- `Localization/en.json` holds every piece of text in English, under a short key such as `fast.end`. Each other language has its own file with the same keys (`fr.json`, `pt-BR.json`, `zh-Hans.json` and so on).
- `Localization/build_catalog.py` checks all the files and writes `WaterFasting/Localizable.xcstrings`, the String Catalog that Xcode builds into the app. Do not edit the catalog by hand; edit the JSON files and run:

  ```sh
  cd ios
  python3 Localization/build_catalog.py
  ```

  It stops with a list of problems if a key is missing, a placeholder such as `%@` or `%lld` does not match the English, a plural form is missing, or an em dash slipped in.
- To change wording, edit `en.json` and the same key in every other file, then run the script. To add text in Swift, call `tr("new.key")` (or `trCount` for counted text), add the key to every file and run the script; it also fails if the code uses a key that is not in `en.json`.
- `Localization/TRANSLATOR_NOTES.md` explains the rules and which strings are built from pieces. Send it with the files to anyone reviewing a translation.
- Arabic reads right to left. The layout flips by itself; the timeline, water meter, clock, phone numbers and source links stay left to right on purpose.
- Research paper titles and author names stay in their original language.

Before release, have a native speaker check at least the safety text in each language: the Today warnings, the check-in results, the refeeding plan and the safety questions in Profile. The translations were written carefully to keep every number and warning, but medical wording deserves a human check. In Xcode, Product, then Scheme, then Edit Scheme, then Run, then Options lets you set App Language to see each one in the simulator.

App Store Connect: add a listing (name, subtitle, description, screenshots) for each language you want to show in the store. App Store Connect has no Swahili listing, so Swahili speakers see the English listing but still get the app in Swahili once installed.

## App Store

Everything for App Store Connect is in `AppStore/`:

- `APP_STORE_CONNECT.md`: every field in order: signing, bundle ID, app record, category, age rating answers, App Privacy answers, pricing and availability, review notes and the screenshot plan.
- `listings/<language>.md`: name, subtitle, promotional text, description and keywords for each store language, ready to paste. `listings/*.json` are the sources; after editing one, run `python3 AppStore/build_listings.py` to check the App Store limits and rebuild the pages.
- `screenshot-maker.html`: open it in Safari or Chrome, drop in simulator screenshots, and it makes captioned App Store images at 1320 x 2868 and 1206 x 2622 in any of the store languages.
- `SUPPORT_PAGE.md`: text for the support page the App Store requires.

`WaterFasting/PrivacyInfo.xcprivacy` is the privacy manifest Apple requires for every upload. It declares that nothing is collected or tracked, and why the app uses UserDefaults (the language setting).

Mac (Designed for iPhone) and Vision Pro availability are already turned off in the build settings. Also untick "Make available on Apple Silicon Macs" in App Store Connect.

## Before you ship

This project was written without access to Xcode, so it has been checked with a Swift parser but not compiled. If the first build shows an error, send me the message and file and I will fix it.

Not done yet:

- RevenueCat paywall (no paid tier has been decided)
