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
  Services/
    FastStore.swift              Single source of truth, JSON cache, all actions
    NotificationService.swift    Milestone alerts and 9:00 / 21:00 check-in reminders
    CloudSync.swift              Optional Firestore backup with Sign in with Apple
  Views/
    RootView.swift               Welcome flow and tab bar
    TodayView.swift              Timer, phase timeline, water, warnings, fast planner
    LogView.swift                Check-in form, graded results, weight, history
    RefeedView.swift             Active refeeding plan and standalone planner
    LearnView.swift              The research, section by section, with sources
    ProfileView.swift            Details, safety check, clinician, reminders, data
    CloudCard.swift              Backup and sync card (only with Firebase)
    Theme.swift, Components.swift
  Assets.xcassets                App icon and accent colour
```

## Safety rules

Taken from the source document and shared with the web app:

- Any absolute contraindication (type 1 diabetes, pregnancy or breastfeeding, eating disorder, CKD 3b to 5, decompensated cirrhosis, acute porphyria, cachexia, BMI under 18.5, under 18) blocks starting a fast.
- Diuretics and type 2 diabetes medicines need confirmed clinical supervision for any fast. Other relative contraindications need the doctor-reviewed confirmation. Osteopenia or osteoporosis caps fasts at 72 hours.
- Every fast over 72 hours needs confirmed clinical supervision.
- Check-ins flag the warning signs, likely low sodium, an orthostatic drop of 20/10 mmHg or more, a standing pulse rise of 30 or more, water outside 1.2 to 2.5 L, and BHB above 7.0 mmol/L.
- Refeeding lasts at least half the fast and uses the ASPEN and NICE risk tiers.

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

`PRIVACY_POLICY.md` is the app's privacy policy, written to match what the code actually does. Publish it as a page on malebolabs.com, then:

1. Open the live page in a browser and copy its exact address.
2. Put that address in `WaterFasting/Models/AppLinks.swift` (the in-app link in Profile, required by guideline 5.1.1) and in App Store Connect.
3. If version 1 ships without cloud backup, delete section 4, section 11 and the Google Firebase row in section 7, and remove the "Account" row from the table in section 1.

## App Store notes

- Category: **Health & Fitness**.
- Mac (Designed for iPhone) and Vision Pro availability are already turned off in the build settings. Also untick "Make available on Apple Silicon Macs" in App Store Connect.
- App Privacy: without Firebase nothing leaves the phone, so "Data Not Collected" is accurate. With cloud backup on, declare Health & Fitness, User ID, Email Address (if shared through Sign in with Apple) and Other User Content, all linked to the user, used for App Functionality, no tracking.
- Health apps get close review under guideline 1.4.1. Keep the disclaimers and the Sources section; they show where every number comes from.
- Screenshots: 1320 x 2868 (6.9-inch) and 1284 x 2778 (6.5-inch). Run the matching simulator and press Cmd+S.

## Before you ship

This project was written without access to Xcode, so it has been checked with a Swift parser but not compiled. If the first build shows an error, send me the message and file and I will fix it.

Not done yet:

- Apple Health (HealthKit) for weight and blood pressure
- Home Screen widget or Live Activity for the timer
- RevenueCat paywall (no paid tier has been decided)
