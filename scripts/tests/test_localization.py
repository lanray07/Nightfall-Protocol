import copy
from contextlib import redirect_stdout
import io
import json
from pathlib import Path
import struct
import sys
import tempfile
import unittest
import zlib

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from localize import (ROOT, coverage, digest, export_metadata, protect, read_json, restore,
                      seed_listing_state, tokens, translate_catalog, translate_listing, validate_listing)
from validate_screenshots import validate_screenshots
from capture_screenshots import run
from curate_screenshots import curate


class FakeTranslator:
    def __init__(self):
        self.calls = []

    def translate(self, texts, target):
        self.calls.append((list(texts), target))
        return [target + " " + text for text in texts]


class LocalizationTests(unittest.TestCase):
    def setUp(self):
        self.listing = read_json(ROOT / "fastlane/localization/listing.json")

    def test_all_eleven_listings_and_eight_captions_are_valid(self):
        validate_listing(self.listing)
        self.assertEqual(len(self.listing["locales"]), 11)
        self.assertEqual(len(self.listing["scenes"]), 8)

    def test_keyword_bytes_not_just_character_count(self):
        self.listing["locales"]["ja"]["keywords"] = "悪夢" * 20
        with self.assertRaisesRegex(ValueError, "keywords"):
            validate_listing(self.listing)

    def test_exports_legal_urls_and_detects_stale_metadata(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            export_metadata(self.listing, root)
            export_metadata(self.listing, root, check=True)
            path = root / "fastlane/metadata/ja/description.txt"
            text = path.read_text(encoding="utf-8")
            self.assertIn(self.listing["terms_url"], text)
            self.assertIn(self.listing["privacy_url"], text)
            path.write_text("out of date", encoding="utf-8")
            with self.assertRaisesRegex(ValueError, "stale"):
                export_metadata(self.listing, root, check=True)

    def test_protected_brand_urls_and_printf_round_trip(self):
        source = "Nightfall Protocol: %2$@ %1$04d %.2f %% https://example.com/privacy"
        protected, replacements = protect(source)
        self.assertEqual(restore(protected, replacements), source)
        self.assertEqual(tokens(source), tokens(restore(protected, replacements)))
        with self.assertRaisesRegex(ValueError, "protected"):
            restore(protected.replace("NFPRESERVE0000", "translated"), replacements)

    def test_preserves_human_translation_and_refreshes_generated_units(self):
        catalog = {"sourceLanguage": "en", "strings": {
            "human": {"localizations": {"en": {"stringUnit": {"value": "Play"}}, "es": {"stringUnit": {"value": "Jugar"}}}},
            "missing": {"localizations": {"en": {"stringUnit": {"value": "Score %d"}}}},
            "ignored": {"shouldTranslate": False, "localizations": {"en": {"stringUnit": {"value": "NF"}}}}
        }}
        translator, state = FakeTranslator(), {}
        locales = {"es-ES": self.listing["locales"]["es-ES"]}
        translate_catalog(catalog, locales, translator, state)
        self.assertEqual(catalog["strings"]["human"]["localizations"]["es"]["stringUnit"]["value"], "Jugar")
        self.assertEqual(len(translator.calls), 1)
        translate_catalog(catalog, locales, translator, state)
        self.assertEqual(len(translator.calls), 1)
        catalog["strings"]["missing"]["localizations"]["en"]["stringUnit"]["value"] = "New score %d"
        translate_catalog(catalog, locales, translator, state)
        self.assertEqual(len(translator.calls), 2)
        catalog["strings"]["missing"]["localizations"]["es"]["stringUnit"]["value"] = "Puntuación %d"
        catalog["strings"]["missing"]["localizations"]["en"]["stringUnit"]["value"] = "Another score %d"
        translate_catalog(catalog, locales, translator, state)
        self.assertEqual(len(translator.calls), 2)

    def test_rejects_damaged_format_strings(self):
        catalog = {"sourceLanguage": "en", "strings": {"score": {"localizations": {"en": {"stringUnit": {"value": "Score %d"}}}}}}
        translator = FakeTranslator()
        translator.translate = lambda texts, target: ["Puntuación"]
        with self.assertRaisesRegex(ValueError, "protected"):
            translate_catalog(catalog, {"es-ES": self.listing["locales"]["es-ES"]}, translator, {})

    def test_changed_listing_is_translated_but_never_silently_truncated(self):
        state = seed_listing_state(self.listing)
        self.listing["locales"]["en-GB"]["subtitle"] = "X" * 30
        translator = FakeTranslator()
        with self.assertRaisesRegex(ValueError, "subtitle"):
            translate_listing(self.listing, {"es-ES": self.listing["locales"]["es-ES"]}, translator, state)

    def test_coverage_does_not_count_english_fallback_as_translation(self):
        catalog = {"sourceLanguage": "en", "strings": {"play": {"localizations": {"en": {"stringUnit": {"value": "Play"}}}}}}
        self.assertEqual(coverage(catalog, {"ja": self.listing["locales"]["ja"]})["ja"]["missing"], 1)

    def test_capture_commands_report_output_and_failures(self):
        with redirect_stdout(io.StringIO()):
            self.assertEqual(run(sys.executable, "-c", "print('ready')", timeout=10), "ready")
            with self.assertRaisesRegex(RuntimeError, "failed"):
                run(sys.executable, "-c", "raise SystemExit(1)", timeout=10)

    def test_stalled_capture_commands_and_cleanup_are_bounded(self):
        with redirect_stdout(io.StringIO()):
            with self.assertRaisesRegex(RuntimeError, "timed out"):
                run(sys.executable, "-c", "import time; time.sleep(60)", timeout=0.2)
            self.assertEqual(run(sys.executable, "-c", "import time; time.sleep(60)",
                                 timeout=0.2, check=False), "")

    def test_screenshot_sets_keep_devices_separate_and_reject_stale_exports(self):
        listing = copy.deepcopy(self.listing)
        listing["devices"] = {name: {**device, "width": 2, "height": 2} for name, device in listing["devices"].items()}
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            paths = []
            for device in listing["devices"]:
                for scene in listing["scenes"]:
                    path = root / "en-GB" / (device + "-" + scene["id"] + ".png")
                    path.parent.mkdir(parents=True, exist_ok=True)
                    self.write_png(path)
                    paths.append(path.relative_to(root).as_posix())
            manifest = {"listing_hash": digest(json.dumps(listing, ensure_ascii=False, sort_keys=True)),
                        "locales": ["en-GB"], "devices": list(listing["devices"]), "screenshots": paths}
            manifest_path = root / "capture-manifest.json"
            manifest_path.write_text(json.dumps(manifest), encoding="utf-8")
            validate_screenshots(listing, root)
            with self.assertRaisesRegex(ValueError, "Placeholder"):
                validate_screenshots(listing, root, store_ready=True)
            with self.assertRaisesRegex(ValueError, "fresh"):
                curate(listing, root, root / "selected")
            with tempfile.TemporaryDirectory() as output_directory:
                selected = Path(output_directory) / "selected"
                curate(listing, root, selected)
                validate_screenshots(listing, selected, store_ready=True)
                self.assertEqual(len(list(selected.rglob("*.png"))), 14)
                self.assertEqual(len(list(root.rglob("*.png"))), 16)
                self.assertNotIn("06-operator-progression", read_json(selected / "capture-manifest.json")["scenes"])
                with self.assertRaisesRegex(ValueError, "fresh"):
                    curate(listing, root, selected)
            (root / paths[0]).unlink()
            with self.assertRaisesRegex(ValueError, "Missing"):
                validate_screenshots(listing, root)
            listing["locales"]["en-GB"]["captions"][0][0] = "Updated caption"
            with self.assertRaisesRegex(ValueError, "stale"):
                validate_screenshots(listing, root)

    def test_unknown_screenshot_scene_is_rejected_before_reading_images(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            manifest = {"listing_hash": digest(json.dumps(self.listing, ensure_ascii=False, sort_keys=True)),
                        "locales": ["en-GB"], "devices": list(self.listing["devices"]),
                        "scenes": ["unknown-scene"], "screenshots": []}
            (root / "capture-manifest.json").write_text(json.dumps(manifest), encoding="utf-8")
            with self.assertRaisesRegex(ValueError, "known scenes"):
                validate_screenshots(self.listing, root)

    @staticmethod
    def write_png(path):
        def chunk(kind, data):
            return struct.pack(">I", len(data)) + kind + data + struct.pack(">I", zlib.crc32(kind + data))
        data = b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", struct.pack(">IIBBBBB", 2, 2, 8, 2, 0, 0, 0))
        data += chunk(b"IDAT", zlib.compress(bytes([0, 20, 40, 60, 100, 120, 140]) * 2)) + chunk(b"IEND", b"")
        path.write_bytes(data)


if __name__ == "__main__":
    unittest.main()
