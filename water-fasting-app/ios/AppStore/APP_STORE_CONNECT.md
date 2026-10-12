# Waterline: App Store Connect guide

Everything to enter, in the order App Store Connect asks for it. Values in `code` are ready to paste.
The store text for each language is in `listings/<language>.md`.

Checked against Apple's App Store Connect Help in October 2026. Apple changes these screens often, so if a
label differs slightly, look for the nearest match.

---

## 1. Before you start: account and signing

**Developer account.** Enrol in the Apple Developer Program (developer.apple.com/programs, 99 USD a year).

> **Enrol as an organisation if you can (Malebo Labs).** Guideline 5.1.1(ix) says apps in highly regulated
> fields such as healthcare "should be submitted by a legal entity that provides the services, and not by an
> individual developer". Waterline is educational, not a healthcare service, so an individual account may well
> pass. An organisation account removes the risk and shows "Malebo Labs" as the seller. It needs a free D-U-N-S
> number for the company, which can take a week or two.

**Register the bundle ID** (developer.apple.com, Certificates, Identifiers & Profiles, Identifiers, +, App IDs, App):

| Field | Value |
| --- | --- |
| Description | `Waterline` |
| Bundle ID (Explicit) | `com.malebolabs.waterline` |
| Capabilities | None for version 1. Tick **Sign in with Apple** only if you ship cloud backup. |

Local reminders do not need the Push Notifications capability.

**Signing in Xcode.** Select the WaterFasting target, then Signing & Capabilities:

- Tick **Automatically manage signing**.
- Team: your developer team.
- Bundle Identifier: `com.malebolabs.waterline` (already set).

Version and build are already set to `1.0` and `1` (General tab). Raise the build number for every upload.

**Upload a build.** In Xcode choose the destination **Any iOS Device (arm64)**, then Product, Archive. In the
Organizer, choose Distribute App, App Store Connect, Upload. The project already declares that it uses no
non-exempt encryption, so there are no export compliance questions, and it includes the privacy manifest
Apple requires (`WaterFasting/PrivacyInfo.xcprivacy`).

---

## 2. Create the app record

App Store Connect, Apps, +, New App:

| Field | Value |
| --- | --- |
| Platforms | `iOS` |
| Name | `Waterline: Water Fasting` |
| Primary Language | `English (U.K.)` |
| Bundle ID | `com.malebolabs.waterline` |
| SKU | `waterline-ios` |
| User Access | Full Access |

If the name is taken, try `Waterline: Fasting Guide` or `Waterline Water Fast`.

---

## 3. App Information (General, App Information)

| Field | Value |
| --- | --- |
| Name | from `listings/en.md` |
| Subtitle | from `listings/en.md` |
| Category, Primary | `Health & Fitness` |
| Category, Secondary | `Education` (or leave empty). Avoid `Medical`: it draws more scrutiny and suggests a clinical tool. |
| Content Rights | **No**, the app does not contain, show or access third-party content. (It links to research papers, which open in Safari; the summaries are original text.) |
| Age Rating | see section 4 |
| License Agreement | Apple's standard licence |

**Localizations.** In the language menu at the top right of App Information, add each language and paste its
name and subtitle from `listings/<language>.md`. The table in `build_listings.py` (`STORE_LANGUAGES`) shows
which App Store language each file goes into; English also covers U.S., Australia and Canada, Spanish covers
Spain and Mexico, and French covers France and Canada.

Swahili is not an App Store Connect language. Swahili speakers see the English page, then get the app in
Swahili once installed.

---

## 4. Age rating

App Information, Age Ratings, Set Up Age Ratings. Answer:

**In-app controls**

| Question | Answer |
| --- | --- |
| Parental Controls | No |
| Age Assurance | No |

**Capabilities**

| Question | Answer | Why |
| --- | --- | --- |
| Unrestricted Web Access | No | Source links open in Safari, outside the app. |
| User-Generated Content | No | Notes stay private on the phone. |
| Messaging and Chat | No | |
| Social Media | No | |
| Advertising | No | |

**Mature themes, sexuality or nudity, violence:** None for every item. Medicine names in the safety check are
medical information, not drug use.

**Medical or wellness**

| Question | Answer |
| --- | --- |
| Medical or Treatment Information | **Frequent** (contraindications, medicine warnings, refeeding guidance) |
| Health or Wellness Topics | **Yes** (fasting and calorie guidance) |

**Chance-based activities:** None, and No for gambling and loot boxes.

Apple will calculate **16+**. On the Additional Information step choose **Override to Higher Age Rating** and
select **18+**. The research covers adults only and the app's own safety check blocks anyone under 18, so the
store rating should match. Leave Made for Kids off and the Age Suitability URL empty.

---

## 5. App Privacy (General, App Privacy)

**Privacy Policy URL:** `https://malebolabs.com/waterline-privacy-policy/`

Then click Get Started for the data questions. The answer depends on whether this version includes cloud
backup (Firebase).

### Version 1 without cloud backup (recommended)

| Question | Answer |
| --- | --- |
| Do you or your third-party partners collect data from this app? | **No, we do not collect data from this app** |

The product page will show **Data Not Collected**. This is accurate: everything stays in a file on the iPhone,
there is no analytics, crash reporting or advertising SDK, and the language setting stays on the device.

Before publishing, edit the policy page as `../README.md` describes (remove section 4, section 11, the Google
Firebase row in section 7, and the Account row in section 1), so the page matches the app.

### Later version with cloud backup

Answer **Yes**, then select these data types. For every one: used for **App Functionality** only,
**linked to the user**, **not used for tracking**.

| Category | Data type | What it is in Waterline |
| --- | --- | --- |
| Health & Fitness | Health | Height, weight, age, sex, safety answers, check-ins (blood pressure, pulse, ketones, symptoms), fasts |
| Contact Info | Email Address | Only if the person shares it through Sign in with Apple |
| Identifiers | User ID | The Firebase account ID |
| User Content | Other User Content | Check-in notes and the clinician's name and phone number |

**Store text.** The listings say "Everything stays on your iPhone". With cloud backup, change that line in every
listing to "No account needed. Your data stays on your iPhone unless you turn on optional backup.", and update
the data questions in `SUPPORT_PAGE.md` the same way.

**Privacy manifest.** Add the same four types to `WaterFasting/PrivacyInfo.xcprivacy` under
`NSPrivacyCollectedDataTypes` (types `NSPrivacyCollectedDataTypeHealth`, `...EmailAddress`, `...UserID`,
`...OtherUserContent`, each with Linked true, Tracking false and purpose
`NSPrivacyCollectedDataTypePurposeAppFunctionality`).

---

## 6. Pricing and Availability

| Field | Value |
| --- | --- |
| Price | Free |
| Availability | All countries or regions, **except China mainland** unless you have an ICP filing number. Apple requires one for new apps there. Simplified Chinese still reaches Singapore, Malaysia and Chinese speakers elsewhere. |
| Pre-orders | Off |

**EU trader status** (Business section, or the prompt in App Information). The EU's Digital Services Act
requires every developer to say whether they are a trader. Malebo Labs is a business, so choose **trader**.
Its address, phone and email then appear on the EU product page. Without this, the app is not shown in EU
storefronts.

---

## 7. The version page (iOS App, 1.0 Prepare for Submission)

For each language, paste from `listings/<language>.md`:

| Field | Source |
| --- | --- |
| Promotional Text | `listings/<language>.md` |
| Description | `listings/<language>.md` |
| Keywords | `listings/<language>.md` (already within 100 bytes) |
| Screenshots | section 8 |

For every language:

| Field | Value |
| --- | --- |
| Support URL | `https://malebolabs.com/waterline-support/` (make this page from `SUPPORT_PAGE.md`) |
| Marketing URL | optional, for example `https://malebolabs.com/waterline/` |
| Version | `1.0` |
| Copyright | `2026 Malebo Labs` |
| Routing App Coverage File | none |

**Build:** pick the build you uploaded (it appears about 15 minutes after the upload finishes).

**App Review Information**

| Field | Value |
| --- | --- |
| Sign-in required | No |
| Contact | your name, phone and `passytotola@gmail.com` |
| Notes | the text below |

```
Waterline is an educational companion for water-only fasting, built from published clinical research. Every source is linked in the Learn tab. It is not a medical device, makes no diagnostic claims and shows a not-medical-advice notice and an emergency reminder throughout.

No account is needed. To try the main flow:
1. Choose a language and tap Continue, then Get started.
2. In Profile, enter a height, weight and age (for example 175 cm, 80 kg, 40) and answer No to every safety question.
3. On Today, choose 24 h and tap Start. The timer, phase timeline, water log and warning signs appear.
4. In Log, save a check-in (for example lying 120/78, standing 97/70) to see how readings are graded.
5. On Today, tap End fast, then open Refeed to see the refeeding plan.

Safety design: any absolute contraindication (type 1 diabetes, pregnancy or breastfeeding, an eating disorder, BMI under 18.5, age under 18 and others) blocks starting a fast. Medicines that need a doctor are flagged. Fasts longer than 72 hours require the person to confirm medical supervision, as in the clinical research. All data stays on the device; nothing is collected.
```

If you ship with cloud backup, add: `Optional backup uses Sign in with Apple (Profile, Backup and sync). Account
deletion is in the same card and revokes the Apple token.`

**Version Release:** "Manually release this version" lets you choose the launch moment.

Then **Add for Review**, and **Submit**.

---

## 8. Screenshots

**Sizes App Store Connect needs** (iPhone only, so no iPad set):

| Set | Size (portrait) | Simulator to use |
| --- | --- | --- |
| iPhone 6.9-inch (Dynamic Island, large) | 1320 x 2868 | iPhone 17 Pro Max or iPhone 16 Pro Max |
| iPhone 6.3-inch (Dynamic Island, medium), required | 1206 x 2622 | iPhone 17 Pro or iPhone 16 Pro |

Up to 10 per set, JPEG or PNG with no transparency. `screenshot-maker.html` makes both sizes as JPEG.

**1. Clean status bar.** With the simulator running, in Terminal:

```sh
xcrun simctl status_bar booted override --time 9:41 --batteryState charged --batteryLevel 100 --wifiBars 3 --cellularBars 4
```

**2. Set up the screens.** Run the app, then:

| # | Screen | How to set it up |
| --- | --- | --- |
| 1 | Today: timer during a fast | Profile: 175 cm, 80 kg, 40, all safety answers No. Today: 48 h, turn on "I started earlier", set the start about 30 hours ago, Start. |
| 2 | Profile: safety check answered | Profile, scrolled so About you and the first safety questions show. |
| 3 | Log: a graded check-in | Log: weight 79.4, ketones 1.4, lying 120/78 pulse 64, standing 97/70 pulse 84, symptom "Lightheaded when standing", Save. Capture the graded result. |
| 4 | Today: warning signs card | Profile: add a clinician (for example Dr Amira Haddad, +44 20 7946 0000). Today, scroll to "End the fast and get help if you". |
| 5 | Refeed: your plan | Refeed tab with the planner at 5 days, scrolled to show the risk level and calories. |
| 6 | Learn: hour by hour | Learn, open "Hour by hour". |
| 7 | Language screen | Tap the flag on Today to open the list. |

Press **Cmd+S** in the simulator for each one. The files land on the Desktop, already at the right size.
Rename them `1.png` to `7.png` in the order above.

**3. Frame them.** Open `screenshot-maker.html` in Safari or Chrome, drop the seven files in, choose the
caption language and size, and click Download all. Do it once for 1320 x 2868 and once for 1206 x 2622
(take the second set on the 6.3-inch simulator).

**4. Other languages.** Switch the app's language with the flag button, take the seven screenshots again, and
make the images with the matching caption language. If a language has no screenshots of its own, App Store
Connect shows the primary language's ones, so you can start with English and add the biggest markets later.

---

## 9. After submission

- Review usually takes one to three days. Health apps sometimes get questions under guideline 1.4.1; answer
  by pointing to the sources in Learn, the safety check and the supervision rule.
- If App Review asks about 5.1.1(ix) (healthcare apps from individuals), see section 1.
- Once approved and released, check the product page in a few storefronts, then add more localized screenshots
  over time.
