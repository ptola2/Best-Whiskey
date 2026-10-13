#!/usr/bin/env python3
"""Checks the translation files and builds WaterFasting/Localizable.xcstrings.

Usage (from water-fasting-app/ios):
    python3 Localization/build_catalog.py           # check, then write the catalog
    python3 Localization/build_catalog.py --check   # check only

en.json is the source. Every other <code>.json holds the same keys in another
language. A value is either a string or, for counted text, an object of CLDR
plural categories ("one", "other" and so on).
"""
import json
import re
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
APP = HERE.parent / "WaterFasting"
CATALOG = APP / "Localizable.xcstrings"
# Keys starting with "infoplist." are Info.plist texts (permission prompts). They go into InfoPlist.xcstrings under
# the Info.plist key name, and their English must match the INFOPLIST_KEY_ build setting in the Xcode project.
INFOPLIST_PREFIX = "infoplist."
INFOPLIST_CATALOG = APP / "InfoPlist.xcstrings"
PROJECT = HERE.parent / "WaterFasting.xcodeproj" / "project.pbxproj"
# Keys starting with "extension." belong to the widget extension, which looks them up with String(localized:).
# They go into WaterlineWidget/Localizable.xcstrings. Everything else the widget shows is written by the app.
EXTENSION_PREFIX = "extension."
EXTENSION_DIR = HERE.parent / "WaterlineWidget"
EXTENSION_CATALOG = EXTENSION_DIR / "Localizable.xcstrings"
EXTENSION_CALL = re.compile(r'String\(localized:\s*"((?:[^"\\]|\\.)*)"')

LANGUAGES = ["ar", "de", "es", "fr", "hi", "id", "it", "ja", "ko", "ms", "nl",
             "pl", "pt-BR", "ru", "sv", "sw", "th", "tr", "vi", "zh-Hans"]

# CLDR cardinal plural categories each language needs.
PLURALS = {
    "en": {"one", "other"},
    "ar": {"zero", "one", "two", "few", "many", "other"},
    "de": {"one", "other"}, "nl": {"one", "other"}, "sv": {"one", "other"},
    "tr": {"one", "other"}, "hi": {"one", "other"}, "sw": {"one", "other"},
    "es": {"one", "many", "other"}, "fr": {"one", "many", "other"},
    "it": {"one", "many", "other"}, "pt-BR": {"one", "many", "other"},
    "pl": {"one", "few", "many", "other"}, "ru": {"one", "few", "many", "other"},
    "ja": {"other"}, "ko": {"other"}, "zh-Hans": {"other"}, "th": {"other"},
    "vi": {"other"}, "id": {"other"}, "ms": {"other"},
}

# Keys built at run time ("phase.\(index).name"). Each pattern lists the ids
# the Swift code fills in, so a missing translation is caught here.
ABSOLUTE = ["t1d", "preg", "ed", "ckd", "liver", "porph", "cachexia"]
RELATIVE = ["diuretic", "t2d", "bpmeds", "lithium", "gout", "bone", "heart"]
REFEED_RISK = ["wtloss", "lytes"]
DYNAMIC_IDS = {
    "phase.*": [str(i) for i in range(8)],
    "risk.*": ["ortho", "hypona", "acid", "gout", "bone"],
    "symptom.*": ["fatigue", "headache", "nausea", "insomnia", "drymouth", "dyspepsia",
                  "backpain", "dizzy", "cramps", "lethargy", "faint", "chest", "confusion",
                  "vomit", "joint", "breathing", "swelling", "breathless"],
    "screen.*.question": ABSOLUTE + RELATIVE + REFEED_RISK,
    "screen.*.why": ABSOLUTE + RELATIVE,
    "screen.*.action": RELATIVE,
    "protocol.*": ["water", "buchinger", "fmd", "adf", "tre"],
    "hormone.*": ["insulin", "bhb", "gh", "igf1", "cortisol", "ft3", "mtor", "uric"],
    "study.*": ["goldhamer", "dai", "oglodek", "pietzner", "scharf"],
    "complication.*": ["sodium", "gout", "ortho", "acid", "bone"],
    "stage.*": ["juice", "fruitVeg", "starch"],
    "tier.*": ["low", "moderate", "high"],
    "before.*": ["doctor", "ease_in", "rest", "water", "refeed"],
}

SPEC = re.compile(r"%(?:(\d+)\$)?(lld|ld|d|@|%)")
ANY_PERCENT = re.compile(r"%")
CALL = re.compile(r'\btr(Count)?\(\s*"((?:[^"\\]|\\.)*)"')
INTERP = re.compile(r"\\\([^)]*\)")

errors = []


def fail(message):
    errors.append(message)


def specifiers(text):
    """Returns ({position: type}, count of literal %%) or None if a % is malformed."""
    found = {}
    next_pos = 1
    literal = 0
    for match in SPEC.finditer(text):
        kind = match.group(2)
        if kind == "%":
            literal += 1
        else:
            kind = "int" if kind in ("lld", "ld", "d") else "obj"
            pos = int(match.group(1)) if match.group(1) else next_pos
            if not match.group(1):
                next_pos += 1
            found[pos] = kind
    if len(ANY_PERCENT.findall(text)) != sum(2 if m.group(2) == "%" else 1 for m in SPEC.finditer(text)):
        return None, literal
    return found, literal


def code_keys():
    literal, patterns = set(), set()
    for path in APP.rglob("*.swift"):
        for match in CALL.finditer(path.read_text(encoding="utf-8")):
            key = match.group(2)
            if INTERP.search(key):
                patterns.add(INTERP.sub("*", key))
            else:
                literal.add(key)
    return literal, patterns


def expand(pattern):
    for prefix, ids in DYNAMIC_IDS.items():
        head = prefix.split("*")[0]
        tail = prefix.split("*")[1]
        if pattern.startswith(head) and (pattern[len(head):].startswith("*")):
            rest = pattern[len(head) + 1:]
            if tail and rest != tail:
                continue
            return [head + i + rest for i in ids]
    return None


def check_value(lang, key, value, source):
    if isinstance(source, dict):
        if not isinstance(value, dict):
            fail(f"{lang}: {key} must be a plural object")
            return
        needed = PLURALS[lang]
        if set(value) != needed:
            fail(f"{lang}: {key} plural categories {sorted(value)} should be {sorted(needed)}")
        texts = list(value.values())
        reference = source["other"]
    else:
        if not isinstance(value, str):
            fail(f"{lang}: {key} must be a string")
            return
        texts = [value]
        reference = source
    ref_specs, _ = specifiers(reference)
    takes_args = bool(ref_specs)
    for text in texts:
        if not text.strip():
            fail(f"{lang}: {key} is empty")
        if "—" in text:
            fail(f"{lang}: {key} contains an em dash")
        if not takes_args:
            # Shown as is, so a percent sign is written once.
            if "%%" in text or re.search(r"%(\d+\$)?(lld|ld|d|@)", text):
                fail(f"{lang}: {key} takes no arguments, so it needs a plain % and no %@ or %lld")
            continue
        specs, literal = specifiers(text)
        if specs is None:
            fail(f"{lang}: {key} has a stray % (write %% for a literal percent sign)")
            continue
        if takes_args:
            if isinstance(source, dict):
                # A plural form may leave the number out ("一天"), but never add one.
                if any(specs.get(p) not in (None, t) for p, t in ref_specs.items()) or set(specs) - set(ref_specs):
                    fail(f"{lang}: {key} specifiers {specs} do not match English {ref_specs}")
            elif specs != ref_specs:
                fail(f"{lang}: {key} specifiers {specs} do not match English {ref_specs}")
            if len(ref_specs) > 1 and re.search(r"%(lld|@)", text):
                fail(f"{lang}: {key} has several arguments, so each needs a position (%1$@)")


def load(lang):
    path = HERE / f"{lang}.json"
    if not path.exists():
        fail(f"{lang}: {path.name} is missing")
        return None
    try:
        return json.loads(path.read_text(encoding="utf-8"))
    except json.JSONDecodeError as exc:
        fail(f"{lang}: {path.name} is not valid JSON ({exc})")
        return None


def main():
    check_only = "--check" in sys.argv
    english = load("en")
    if english is None:
        print("\n".join(errors))
        return 1

    literal, patterns = code_keys()
    used = set(literal)
    extension_used = {m.group(1) for path in EXTENSION_DIR.rglob("*.swift")
                      for m in EXTENSION_CALL.finditer(path.read_text(encoding="utf-8"))}
    used |= extension_used
    for pattern in patterns:
        keys = expand(pattern)
        if keys is None:
            fail(f"code: no id list for dynamic key {pattern}; add it to DYNAMIC_IDS")
        else:
            used.update(keys)
    for key in sorted(used - set(english)):
        fail(f"en: {key} is used in the code but missing from en.json")
    for key in sorted(set(english) - used):
        if not key.startswith(INFOPLIST_PREFIX):
            fail(f"en: {key} is in en.json but not used in the code")
    project = PROJECT.read_text(encoding="utf-8")
    for key in sorted(k for k in english if k.startswith(INFOPLIST_PREFIX)):
        name = key[len(INFOPLIST_PREFIX):]
        settings = set(re.findall(rf'INFOPLIST_KEY_{name} = "((?:[^"\\]|\\.)*)";', project))
        if settings != {english[key]}:
            fail(f"en: {key} does not match INFOPLIST_KEY_{name} in project.pbxproj")
    for key, value in english.items():
        check_value("en", key, value, value)

    translations = {}
    for lang in LANGUAGES:
        data = load(lang)
        if data is None:
            continue
        translations[lang] = data
        for key in sorted(set(english) - set(data)):
            fail(f"{lang}: missing {key}")
        for key in sorted(set(data) - set(english)):
            fail(f"{lang}: unknown key {key}")
        for key, source in english.items():
            if key in data:
                check_value(lang, key, data[key], source)

    if errors:
        print(f"{len(errors)} problem(s):")
        print("\n".join(errors))
        return 1
    print(f"OK: {len(english)} keys, {len(translations)} translations")
    if check_only:
        return 0

    def unit(text):
        return {"stringUnit": {"state": "translated", "value": text}}

    def entry(value):
        if isinstance(value, dict):
            return {"variations": {"plural": {cat: unit(text) for cat, text in value.items()}}}
        return unit(value)

    app_strings, plist_strings, extension_strings = {}, {}, {}
    for key in sorted(english):
        localizations = {"en": entry(english[key])}
        for lang in LANGUAGES:
            localizations[lang] = entry(translations[lang][key])
        item = {"extractionState": "manual", "localizations": localizations}
        if key.startswith(INFOPLIST_PREFIX):
            plist_strings[key[len(INFOPLIST_PREFIX):]] = item
        elif key.startswith(EXTENSION_PREFIX):
            extension_strings[key] = item
        else:
            app_strings[key] = item
    for path, strings in ((CATALOG, app_strings), (INFOPLIST_CATALOG, plist_strings),
                          (EXTENSION_CATALOG, extension_strings)):
        catalog = {"sourceLanguage": "en", "strings": strings, "version": "1.0"}
        path.write_text(json.dumps(catalog, ensure_ascii=False, indent=2, sort_keys=True) + "\n", encoding="utf-8")
        print(f"Wrote {path.relative_to(HERE.parent)}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
