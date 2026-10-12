#!/usr/bin/env python3
"""Checks the App Store listings and writes copy-and-paste pages.

Usage (from water-fasting-app/ios):
    python3 AppStore/build_listings.py           # check, then write AppStore/listings/<lang>.md
    python3 AppStore/build_listings.py --check   # check only

listings/en.json is the source. Each other <code>.json holds the same fields in another language.
The limits are App Store Connect's: name and subtitle 30 characters, promotional text 170,
description 4000, keywords 100 bytes.
"""
import json
import re
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
LISTINGS = HERE / "listings"
MAKER = HERE / "screenshot-maker.html"

# App language code -> App Store Connect language(s) the listing is pasted into.
STORE_LANGUAGES = {
    "en": ["English (U.K.)", "English (U.S.)", "English (Australia)", "English (Canada)"],
    "ar": ["Arabic"],
    "de": ["German"],
    "es": ["Spanish (Spain)", "Spanish (Mexico)"],
    "fr": ["French", "French (Canada)"],
    "hi": ["Hindi"],
    "id": ["Indonesian"],
    "it": ["Italian"],
    "ja": ["Japanese"],
    "ko": ["Korean"],
    "ms": ["Malay"],
    "nl": ["Dutch"],
    "pl": ["Polish"],
    "pt-BR": ["Portuguese (Brazil)"],
    "ru": ["Russian"],
    "sv": ["Swedish"],
    "th": ["Thai"],
    "tr": ["Turkish"],
    "vi": ["Vietnamese"],
    "zh-Hans": ["Chinese (Simplified)"],
}
FIELDS = ["name", "subtitle", "promotional_text", "description", "keywords", "screenshots"]

errors = []


def check(lang, data, english):
    for field in FIELDS:
        if field not in data:
            errors.append(f"{lang}: missing {field}")
    if errors and errors[-1].startswith(f"{lang}: missing"):
        return
    limits = {"name": 30, "subtitle": 30, "promotional_text": 170, "description": 4000}
    for field, limit in limits.items():
        if len(data[field]) > limit:
            errors.append(f"{lang}: {field} is {len(data[field])} characters (limit {limit})")
        if not data[field].strip():
            errors.append(f"{lang}: {field} is empty")
    size = len(data["keywords"].encode("utf-8"))
    if size > 100:
        errors.append(f"{lang}: keywords are {size} bytes (limit 100)")
    if ", " in data["keywords"]:
        errors.append(f"{lang}: keywords have spaces after commas, which waste bytes")
    for field in ("name", "subtitle", "keywords"):
        if "\u00a0" in data[field] or "\u202f" in data[field]:
            errors.append(f"{lang}: {field} has a non-breaking space; use a plain space in App Store fields")
    if "Waterline" not in data["name"]:
        errors.append(f"{lang}: name must contain Waterline")
    shots = data["screenshots"]
    if len(shots) != len(english["screenshots"]):
        errors.append(f"{lang}: {len(shots)} screenshot captions, English has {len(english['screenshots'])}")
    for i, shot in enumerate(shots):
        for part in ("title", "subtitle"):
            if not shot.get(part, "").strip():
                errors.append(f"{lang}: screenshot {i + 1} has no {part}")
    text = json.dumps(data, ensure_ascii=False)
    if "—" in text:
        errors.append(f"{lang}: contains an em dash")
    for number in sorted(set(re.findall(r"\d+", english["description"]))):
        if number not in re.findall(r"\d+", data["description"].replace(" ", " ")):
            errors.append(f"{lang}: description is missing the number {number}")


def page(lang, data):
    stores = ", ".join(STORE_LANGUAGES[lang])
    out = [f"# Waterline App Store listing: {lang}", "", f"Paste into App Store Connect for: **{stores}**.", ""]
    for field, label in [("name", "Name (App Information)"), ("subtitle", "Subtitle (App Information)"),
                         ("promotional_text", "Promotional Text"), ("description", "Description"),
                         ("keywords", "Keywords")]:
        value = data[field]
        count = f"{len(value.encode('utf-8'))} of 100 bytes" if field == "keywords" else f"{len(value)} characters"
        out += [f"## {label}", "", f"_{count}_", "", "```", value, "```", ""]
    out += ["## Screenshot captions", "", "Made by screenshot-maker.html. Listed here for reference.", ""]
    for i, shot in enumerate(data["screenshots"], 1):
        out.append(f"{i}. **{shot['title']}**: {shot['subtitle']}")
    return "\n".join(out) + "\n"


def main():
    english = json.loads((LISTINGS / "en.json").read_text(encoding="utf-8"))
    all_data = {}
    for lang in STORE_LANGUAGES:
        path = LISTINGS / f"{lang}.json"
        if not path.exists():
            errors.append(f"{lang}: {path.name} is missing")
            continue
        try:
            data = json.loads(path.read_text(encoding="utf-8"))
        except json.JSONDecodeError as exc:
            errors.append(f"{lang}: invalid JSON ({exc})")
            continue
        check(lang, data, english)
        all_data[lang] = data
    if errors:
        print(f"{len(errors)} problem(s):")
        print("\n".join(errors))
        return 1
    print(f"OK: {len(all_data)} listings")
    if "--check" in sys.argv:
        return 0
    for lang, data in all_data.items():
        (LISTINGS / f"{lang}.md").write_text(page(lang, data), encoding="utf-8")
    captions = {lang: [{"title": s["title"], "subtitle": s["subtitle"]} for s in data["screenshots"]]
                for lang, data in all_data.items()}
    html = MAKER.read_text(encoding="utf-8")
    block = json.dumps(captions, ensure_ascii=False, indent=1)
    html, count = re.subn(r'(<script id="captions" type="application/json">)(.*?)(</script>)',
                          lambda m: m.group(1) + "\n" + block + "\n" + m.group(3), html, flags=re.S)
    if count != 1:
        print("screenshot-maker.html has no captions block")
        return 1
    MAKER.write_text(html, encoding="utf-8")
    print(f"Wrote {len(all_data)} listing pages and updated screenshot-maker.html")
    return 0


if __name__ == "__main__":
    sys.exit(main())
