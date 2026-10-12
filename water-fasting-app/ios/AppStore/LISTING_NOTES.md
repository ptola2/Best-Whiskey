# Notes for translating the App Store listing

Source: `listings/en.json`. Write `listings/<code>.json` with the same fields, then run:

```sh
python3 AppStore/build_listings.py --check
```

## Fields and limits (App Store Connect)

| Field | Limit | Notes |
| --- | --- | --- |
| `name` | 30 characters | "Waterline" plus the usual term for water fasting in your language, for example "Waterline : jeûne hydrique". Keep "Waterline" in Latin letters. |
| `subtitle` | 30 characters | Short and concrete. Shown under the name in search. |
| `promotional_text` | 170 characters | One or two sentences. |
| `description` | 4000 characters | Keep the section structure, the bullets (•) and the IMPORTANT section word for word in meaning. |
| `keywords` | 100 bytes (UTF-8) | Comma separated, no spaces after commas. Not a literal translation: use the words people in your language really search for (water fast, fasting tracker, refeeding, ketosis and so on). Do not repeat words already in the name or subtitle, and no competitor or brand names. Arabic and Cyrillic letters take 2 bytes each, and Hindi, Thai, Chinese, Japanese and Korean characters take 3, so fewer words fit. |
| `screenshots` | 7 captions | Keep `screen` in English (it tells the person taking screenshots which screen to use). Translate `title` (aim for 30 characters or fewer) and `subtitle` (aim for 50 or fewer). |

## Rules

- Use the same words the app uses. Read `../Localization/<code>.json` for the app's own terms (refeeding, check-in, clinician, safety check, the tab names) and match them.
- Apple reviews health apps closely. Do not add claims: no "safe", "cure", "treat", "detox", "lose weight" or results promises beyond the English. Keep every caveat in the IMPORTANT section.
- Keep every number from the English description (72, 1.2 to 2.5 L, type 1, 21 languages). Use your language's decimal separator.
- No em dashes.
- Write naturally for an app store page in your language, in the register the app uses.
