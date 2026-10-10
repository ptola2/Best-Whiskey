# Waterline

A water fasting companion built from the research summary *Clinical Physiology, Therapeutic Applications, and Safety Profiles of Prolonged Water-Only Fasting*. It is a single HTML file with no build step and no dependencies beyond Google Fonts.

Open `index.html` in any browser to run it. On a phone, open it and use "Add to Home Screen" to get an app icon.

## What it does

| Tab | Purpose |
| --- | --- |
| **Today** | Live fast timer, progress ring, and a timeline shaded by metabolic phase (0 to 12 h, 12 to 36 h, 36 to 72 h, the 72-hour threshold, keto-adaptation, deep ketosis, prolonged, extreme). Shows the current phase, the next milestone, a daily water tracker against the 1.2 to 2.5 L target, the risk windows that apply to the current day, and the signs that mean ending the fast. When idle, it plans a fast. |
| **Log** | Check-ins for weight, blood ketones (BHB), lying and standing blood pressure and pulse, symptoms and notes. Each check-in is graded **No warning signs**, **Caution** or **Stop and get help**, with the reason. Also shows weight change against the expected curve and past fasts. |
| **Refeed** | Builds a refeeding plan: at least half the fast length, a risk tier (lower, moderate, significant) from fast length, BMI and refeeding risk answers, a calorie range, salt and fluid rules, monitoring, and a day-by-day schedule (diluted juice, then fruit and steamed vegetables, then starches and plant fats). Works as a standalone planner when no fast is running. |
| **Learn** | The research in plain language: fasting types compared, hour-by-hour changes, hormone table, key studies, side effect rates, refeeding syndrome, contraindications and sources. |
| **Profile** | Height, weight, age and sex (for BMI and calorie estimates), the safety check, clinician contact, and data deletion. |

## Safety rules built in

These come straight from the source document.

- **Absolute contraindications block the app from starting a fast:** type 1 diabetes, pregnancy or breastfeeding, current or past eating disorder, CKD stage 3b to 5, decompensated cirrhosis, acute porphyria, cachexia or severe sarcopenia, and BMI under 18.5. Under 18 is also blocked as a general precaution.
- **Relative contraindications** (diuretics, type 2 diabetes medicines, blood pressure medicines, lithium, gout, osteopenia or osteoporosis, heart disease) require the user to confirm a doctor has reviewed the fast. Diuretics and type 2 diabetes medicines also require confirmed clinical supervision for any length. Osteopenia or osteoporosis caps fasts at 72 hours.
- **Any fast longer than 72 hours** requires the user to confirm a clinician is supervising it.
- **Check-in grading** flags warning signs (fainting, chest pain, confusion, vomiting, hot swollen joint, fast deep breathing, swelling, breathlessness), likely low sodium, an orthostatic drop of 20/10 mmHg or more, a standing pulse rise of 30 or more, water intake outside 1.2 to 2.5 L, and BHB above 7.0 mmol/L.
- **Refeeding** follows the ASPEN and NICE tiers in the source. The moderate-tier starting range (10 to 20 kcal/kg/day) uses the ASPEN starting range because that value was missing from the source table.

## Data

- When opened as a Claude artifact, data saves privately to the signed-in user's account. Other viewers cannot see it.
- When opened as a plain file, data saves in that browser's local storage on that device only.
- The first visit shows a clearly labelled example fast so the screens are not empty. Nothing from the example is saved.

## Not medical advice

Waterline is an educational tool. The research it is built on restricts fasts longer than 72 hours to medically supervised settings.

## Ideas for next steps

- Native iOS version in SwiftUI with HealthKit for weight and blood pressure, and local notifications for check-in reminders.
- Installable PWA (manifest and service worker) for offline use.
- Weight and ketone trend charts across a fast.
- Export of check-ins as a PDF or CSV to share with a clinician.
