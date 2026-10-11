# Translator notes

Waterline is a safety companion for water-only fasting. Much of the text is
medical safety guidance, so accuracy matters more than style. Read the English
in `en.json`, write the same keys in `<language>.json`, then run:

```sh
python3 Localization/build_catalog.py
```

It checks every file and rebuilds `WaterFasting/Localizable.xcstrings`. Fix
anything it reports before committing.

## Rules

- Keep every key. Translate values only.
- Keep each placeholder exactly as written: `%@` is text, `%lld` is a whole
  number, and `%1$@`, `%2$lld` mark position. You may move positioned
  placeholders around the sentence, but do not add, drop or retype them.
- In a string that has placeholders, a literal percent sign is `%%`. In a
  string with no placeholders, write a single `%`.
- Counted strings (`count.*`) are objects of plural forms. Use exactly the
  CLDR categories your language needs (the script lists them). A form may
  leave out the number only when the language's grammar calls for it.
- No em dashes. Use a colon, comma or full stop instead.
- Keep these as they are: Waterline, ASPEN, NICE, CTCAE, BHB, HOMA-IR, IGF-1,
  mTORC1, AMPK, LC3-II, Beclin-1, ECG, Mifflin-St Jeor, SGLT2, ARFID, Free T3,
  Grade 3, and units such as mmHg, mmol/L, mEq, mg/dL, kcal, kg, cm, mL and L.
  Medicine and condition names should use the common medical term in your
  language, with the plain-language version where the English gives one.
- Write plainly and calmly. Address the reader directly, using the register a
  consumer health app normally uses in your language, and keep it consistent.
- Use your language's own quotation marks and number words.

## Text that is assembled from pieces

| Key | How it is used |
| --- | --- |
| `stop.title` + `stop.*` | A heading followed by a bulleted list. English uses a lead-in ("End the fast and get help if you") with list items that finish the sentence. If that does not work in your language, make the heading complete on its own (ending with a colon) and make each item a standalone phrase. |
| `refeed_warnings.title` + `refeed_warnings.*` | Same pattern as above. |
| `refeed.reason.*` | Short lowercase phrases joined with ", " and placed in `refeed.plan.for_you` ("For you: %@."). |
| `assess.warnings` | `%1$@` is a list of symptom names (`symptom.*`) joined with "; ". `%2$@` is a full sentence (`assess.action.*`). |
| `profile.summary.incomplete` | `%@` is either `count.questions_left` or `profile.summary.add_details`. |
| `fmt.hours`, `count.days` | A fast length such as "72 h" or "5 days". It is placed into `timer.day_of_plan`, `timer.to_go`, `fast.target_reached.title`, `notify.target.body`, `plan.start` and `history.target`. Phrase those sentences so a length in its basic form fits (for example "Day %1$lld · %2$@ plan" style wording) rather than relying on case endings. |
| `fmt.days_hours`, `fmt.hours_minutes`, `fmt.minutes` | A running timer ("2 d 5 h"). Use the short unit abbreviations people expect in your language. |
| `refeed_today.then` | The separator between refeeding stage titles in one heading, including its spaces (", then "). |
| `common.title_and_reason` | A question and its explanation shown as one sentence. |
| `timer.supervised` | Appended after the plan line as " · supervised". |
| `phase.*.range` | Short ranges shown above each phase name ("12 to 36 h", "Days 5 to 7"). |
| `learn.stat.*` | Captions under a large number. `learn.stat.grade3` sits under "20/28/32". |
| `history.worst.*`, `level.*` | Short status labels in coloured pills. Keep them short. |
| `unit.*` | Units shown next to input fields. |
