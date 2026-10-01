#!/usr/bin/env python3
"""Export App Store copy and optionally translate missing Swift string units."""

import argparse
import hashlib
import html
import json
import os
from pathlib import Path
import re
import sys
import time
import urllib.error
import urllib.parse
import urllib.request

ROOT = Path(__file__).resolve().parents[1]
FIELDS = ("subtitle", "keywords", "promotional_text", "description", "release_notes", "terms_label", "privacy_label")
LIMITS = {"name": 30, "subtitle": 30, "keywords": 100, "promotional_text": 170, "description": 4000}
PRINTF = re.compile(r"%(?:\d+\$)?[-+ #0]*(?:\d+|\*)?(?:\.(?:\d+|\*))?(?:hh|ll|h|l|z|t|j|L)?[@diuoxXfFeEgGaAcsp%]")
PROTECTED = re.compile(r"https?://[^\s]+|Nightfall Protocol|" + PRINTF.pattern)


def read_json(path):
    with path.open(encoding="utf-8") as handle:
        return json.load(handle)


def save_text(path, text):
    path.parent.mkdir(parents=True, exist_ok=True)
    if path.exists() and path.read_text(encoding="utf-8") == text:
        return
    temporary = path.with_suffix(path.suffix + ".tmp")
    temporary.write_text(text, encoding="utf-8", newline="\n")
    temporary.replace(path)


def save_json(path, data):
    save_text(path, json.dumps(data, ensure_ascii=False, indent=2) + "\n")


def digest(text):
    return hashlib.sha256(text.encode("utf-8")).hexdigest()


def tokens(text):
    return sorted(PROTECTED.findall(text))


def protect(text):
    replacements = []

    def replace(match):
        token = "NFPRESERVE%04d" % len(replacements)
        replacements.append((token, match.group()))
        return token

    return PROTECTED.sub(replace, text), replacements


def restore(text, replacements):
    for token, value in replacements:
        if text.count(token) != 1:
            raise ValueError("Translation changed a protected placeholder, URL or brand name")
        text = text.replace(token, value)
    return text


class GoogleTranslator:
    def __init__(self, key):
        if not key:
            raise ValueError("Set GOOGLE_TRANSLATE_API_KEY to translate; export and validation need no key")
        self.key = key

    def translate(self, texts, target):
        protected = [protect(text) for text in texts]
        url = "https://translation.googleapis.com/language/translate/v2?" + urllib.parse.urlencode({"key": self.key})
        body = json.dumps({"q": [entry[0] for entry in protected], "source": "en", "target": target, "format": "text"}).encode("utf-8")
        request = urllib.request.Request(url, data=body, headers={"Content-Type": "application/json"}, method="POST")
        for attempt in range(3):
            try:
                with urllib.request.urlopen(request, timeout=45) as response:
                    data = json.load(response)
                translated = data["data"]["translations"]
                if len(translated) != len(texts):
                    raise ValueError("Translation response has the wrong number of strings")
                return [restore(html.unescape(entry["translatedText"]), pair[1]) for entry, pair in zip(translated, protected)]
            except urllib.error.HTTPError as error:
                if error.code in (429, 500, 502, 503, 504) and attempt < 2:
                    time.sleep(2 ** attempt)
                    continue
                raise RuntimeError("Translation service returned HTTP %s" % error.code) from None
            except urllib.error.URLError:
                raise RuntimeError("Could not reach the translation service") from None


def batches(entries):
    batch, length = [], 0
    for entry in entries:
        size = len(entry[1])
        if batch and (len(batch) >= 50 or length + size > 4000):
            yield batch
            batch, length = [], 0
        batch.append(entry)
        length += size
    if batch:
        yield batch


def description(listing, locale):
    return (locale["description"].strip() + "\n\n" + locale["terms_label"] + ": " + listing["terms_url"]
            + "\n" + locale["privacy_label"] + ": " + listing["privacy_url"])


def validate_listing(listing):
    if not 1 <= len(listing["scenes"]) <= 10:
        raise ValueError("Provide 1 to 10 screenshot scenes per device")
    ids = [scene["id"] for scene in listing["scenes"]]
    if len(set(ids)) != len(ids) or any(not re.fullmatch(r"[0-9]{2}-[a-z0-9-]+", key) for key in ids):
        raise ValueError("Screenshot IDs must be unique, ordered filename-safe identifiers")
    for code, locale in listing["locales"].items():
        values = {"name": listing["name"], **locale, "description": description(listing, locale)}
        for field, limit in LIMITS.items():
            value = values[field]
            length = len(value.encode("utf-8")) if field == "keywords" else len(value)
            if not value.strip() or length > limit:
                raise ValueError("%s %s: %s exceeds limit %s or is empty" % (code, field, length, limit))
        keywords = locale["keywords"].split(",")
        if any(not word or word != word.strip() for word in keywords) or len(set(word.casefold() for word in keywords)) != len(keywords):
            raise ValueError("%s: keywords must be unique, comma-separated terms without outer spaces" % code)
        if len(locale["captions"]) != len(ids) or any(len(pair) != 2 or not all(pair) for pair in locale["captions"]):
            raise ValueError("%s: each screenshot needs a headline and supporting line" % code)


def export_metadata(listing, root, check=False):
    for code, locale in listing["locales"].items():
        values = {field: locale[field] for field in ("subtitle", "keywords", "promotional_text", "release_notes")}
        values.update({"name": listing["name"], "copyright": listing["copyright"], "support_url": listing["support_url"],
                       "privacy_url": listing["privacy_url"], "description": description(listing, locale)})
        for field, value in values.items():
            path = root / "fastlane" / "metadata" / code / (field + ".txt")
            expected = value.strip() + "\n"
            if check:
                if not path.exists() or path.read_text(encoding="utf-8") != expected:
                    raise ValueError("Metadata is missing or stale: %s; run scripts/localize.py" % path)
            else:
                save_text(path, expected)


def translate_catalog(catalog, locales, translator, state):
    source_language = catalog["sourceLanguage"]
    for code, locale in locales.items():
        language = locale["language"]
        if language == source_language:
            continue
        pending = []
        for key, entry in catalog["strings"].items():
            if entry.get("shouldTranslate") is False:
                continue
            source = entry.get("localizations", {}).get(source_language, {}).get("stringUnit", {}).get("value")
            if source is None:
                continue
            unit = entry.get("localizations", {}).get(language, {}).get("stringUnit", {})
            previous = state.get(language + "/" + key)
            generated = previous and unit.get("value") and digest(unit["value"]) == previous["translation"]
            if unit.get("value") and (not generated or previous["source"] == digest(source)):
                continue
            pending.append((key, source))
        print("%s: %d app strings to translate" % (code, len(pending)), flush=True)
        for batch in batches(pending):
            values = translator.translate([text for _, text in batch], locale["google_target"])
            for (key, source), value in zip(batch, values):
                if not value.strip() or tokens(value) != tokens(source):
                    raise ValueError("Invalid protected text in %s/%s" % (code, key))
                catalog["strings"][key].setdefault("localizations", {})[language] = {"stringUnit": {"state": "needs_review", "value": value}}
                state[language + "/" + key] = {"source": digest(source), "translation": digest(value)}


def translate_listing(listing, locales, translator, cache):
    source = listing["locales"][listing["source_locale"]]
    source_hash = digest(json.dumps({field: source[field] for field in (*FIELDS, "captions")}, sort_keys=True, ensure_ascii=False))
    for code, locale in locales.items():
        if code == listing["source_locale"]:
            continue
        previous = cache.get(code)
        if previous is None:
            # The checked-in launch copy is curated; the first run records its source.
            cache[code] = {"source": source_hash}
            continue
        if previous["source"] == source_hash:
            continue
        texts = [source[field] for field in FIELDS] + [text for pair in source["captions"] for text in pair]
        values = []
        for batch in batches(list(enumerate(texts))):
            values.extend(translator.translate([text for _, text in batch], locale["google_target"]))
        candidate = dict(locale)
        for field, value in zip(FIELDS, values):
            candidate[field] = value
        candidate["keywords"] = ",".join(word.strip() for word in re.split(r"[,，،]", candidate["keywords"]))
        caption_values = values[len(FIELDS):]
        candidate["captions"] = [caption_values[index:index + 2] for index in range(0, len(caption_values), 2)]
        listing["locales"][code] = candidate
        validate_listing(listing)
        cache[code] = {"source": source_hash}


def seed_listing_state(listing):
    source = listing["locales"][listing["source_locale"]]
    source_hash = digest(json.dumps({field: source[field] for field in (*FIELDS, "captions")}, sort_keys=True, ensure_ascii=False))
    return {code: {"source": source_hash} for code in listing["locales"] if code != listing["source_locale"]}


def coverage(catalog, locales):
    result = {}
    source = catalog["sourceLanguage"]
    entries = [entry for entry in catalog["strings"].values() if entry.get("shouldTranslate") is not False and "stringUnit" in entry.get("localizations", {}).get(source, {})]
    for code, locale in locales.items():
        missing = sum(not entry.get("localizations", {}).get(locale["language"], {}).get("stringUnit", {}).get("value") for entry in entries)
        result[code] = {"total": len(entries), "missing": missing}
    return result


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--check", action="store_true", help="Validate copy and confirm generated metadata is current")
    parser.add_argument("--translate", action="store_true", help="Translate missing app strings and changed English listing copy")
    parser.add_argument("--locales", help="Comma-separated App Store locale codes; default: all eleven")
    args = parser.parse_args()
    if args.check and args.translate:
        parser.error("--check and --translate are mutually exclusive")
    listing_path = ROOT / "fastlane/localization/listing.json"
    catalog_path = ROOT / "NightfallProtocol/Resources/Localizable.xcstrings"
    state_path = ROOT / "fastlane/localization/translation-state.json"
    listing, catalog = read_json(listing_path), read_json(catalog_path)
    codes = args.locales.split(",") if args.locales else list(listing["locales"])
    if any(code not in listing["locales"] for code in codes):
        parser.error("Unknown locale; choose from " + ",".join(listing["locales"]))
    locales = {code: listing["locales"][code] for code in codes}
    state = read_json(state_path) if state_path.exists() else {"app": {}, "listing": seed_listing_state(listing)}
    validate_listing(listing)
    if args.check and state["listing"] != seed_listing_state(listing):
        raise ValueError("English listing copy changed; refresh all target locales with --translate before uploading")
    if args.translate:
        translator = GoogleTranslator(os.environ.get("GOOGLE_TRANSLATE_API_KEY"))
        translate_catalog(catalog, locales, translator, state["app"])
        translate_listing(listing, locales, translator, state["listing"])
        save_json(catalog_path, catalog)
        save_json(listing_path, listing)
        save_json(state_path, state)
    export_metadata(listing, ROOT, args.check)
    if not args.check and not state_path.exists():
        save_json(state_path, state)
    for code, counts in coverage(catalog, locales).items():
        print("%s: store copy valid; app translation coverage %d/%d" % (code, counts["total"] - counts["missing"], counts["total"]))


if __name__ == "__main__":
    try:
        main()
    except (ValueError, RuntimeError) as error:
        print("Localization: %s" % error, file=sys.stderr)
        sys.exit(1)
