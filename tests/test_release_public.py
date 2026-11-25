"""Synthetic release metadata fixtures, independent of macOS or credentials."""
import base64
import importlib.machinery
import importlib.util
from pathlib import Path
import plistlib
import sys
import tempfile
import unittest
import zipfile

ROOT = Path(__file__).resolve().parents[1]
LOADER = importlib.machinery.SourceFileLoader("release_public", str(ROOT / "scripts/release-public"))
SPEC = importlib.util.spec_from_loader(LOADER.name, LOADER)
GATE = importlib.util.module_from_spec(SPEC)
LOADER.exec_module(GATE)
BASE = "https://updates.example.org/tipwink/public"
FEED = BASE + "/appcast.xml"
KEY = base64.b64encode(bytes(32)).decode()
SIG = base64.b64encode(bytes(64)).decode()


def plist(**overrides):
    return dict(CFBundleIdentifier=GATE.BUNDLE, CFBundleShortVersionString="0.7.1",
                CFBundleVersion="16", LSMinimumSystemVersion="26.0",
                SUFeedURL=FEED, SUPublicEDKey=KEY, SURequireSignedFeed=True,
                SUVerifyUpdateBeforeExtraction=True) | overrides


def appcast(**value):
    bits = dict(version="0.7.1", build="16", minimum="26.0", signature=SIG,
                url=BASE + "/Tipwink-0.7.1-macOS-arm64.zip", size="123",
                extra="") | value
    return '''<?xml version="1.0" encoding="utf-8"?>
<rss xmlns:sparkle="http://www.andymatuschak.org/xml-namespaces/sparkle"><channel><item>
<sparkle:shortVersionString>{version}</sparkle:shortVersionString>
<sparkle:version>{build}</sparkle:version>
<sparkle:minimumSystemVersion>{minimum}</sparkle:minimumSystemVersion>
<enclosure url="{url}" length="{size}" sparkle:edSignature="{signature}"/>
{extra}
</item></channel></rss>'''.format(**bits)


class ReleaseGateTest(unittest.TestCase):
    def test_final_package_requires_expected_configuration(self):
        with tempfile.TemporaryDirectory() as temp:
            candidate = Path(temp) / "Tipwink-macOS-arm64.zip"
            with zipfile.ZipFile(candidate, "w") as zipped:
                zipped.writestr("Tipwink.app/Contents/Info.plist", plistlib.dumps(plist()))
            self.assertEqual(GATE.validate_package(GATE.plist_from_zip(candidate), FEED, KEY),
                             ("0.7.1", "16", "26.0"))

    def test_rejects_unconfigured_or_wrong_channel_packages(self):
        for changes in (dict(SUFeedURL="", SUPublicEDKey=""), dict(SUFeedURL=FEED.replace("/public/", "/pilot/")),
                        dict(SUPublicEDKey=base64.b64encode(bytes([1]) * 32).decode()),
                        dict(SURequireSignedFeed=False), dict(SUVerifyUpdateBeforeExtraction=False)):
            with self.subTest(changes=changes), self.assertRaises(GATE.GateError):
                GATE.validate_package(plist(**changes), FEED, KEY)

    def test_requires_stable_credential_free_production_url(self):
        self.assertEqual(GATE.feed_base(FEED), BASE)
        for bad in (FEED.replace("https:", "http:"), FEED + "?token=fake", FEED + "#extra",
                    FEED.replace("/public/", "/pilot/"), FEED.replace("/public/", "/staging/"),
                    FEED.replace("updates.example", "fake@updates.example")):
            with self.subTest(bad=bad), self.assertRaises(GATE.GateError):
                GATE.feed_base(bad)

    def test_appcast_enclosure_must_describe_exact_full_package(self):
        with tempfile.TemporaryDirectory() as temp:
            candidate = Path(temp) / "appcast.xml"
            candidate.write_text(appcast(minimum="26.0.0", extra="<sparkle:hardwareRequirements>arm64</sparkle:hardwareRequirements>"))
            self.assertEqual(GATE.check_appcast(candidate, "0.7.1", "16", "26.0", BASE, 123),
                             (BASE + "/Tipwink-0.7.1-macOS-arm64.zip", SIG))
            for changes in (dict(version="0.7.0"), dict(build="15"), dict(size="124"),
                            dict(minimum="27.0"), dict(signature=""), dict(url=BASE + "/current.zip"),
                            dict(extra="<sparkle:channel>beta</sparkle:channel>")):
                with self.subTest(changes=changes):
                    candidate.write_text(appcast(**changes))
                    with self.assertRaises(GATE.GateError):
                        GATE.check_appcast(candidate, "0.7.1", "16", "26.0", BASE, 123)

    def test_rejects_malformed_marketing_or_build_versions(self):
        for version, build in (("v0.7.1", 16), ("0.07.1", 16), ("0.7.1", 0), ("0.7.1", "16x")):
            with self.subTest(version=version, build=build), self.assertRaises(GATE.GateError):
                GATE.numbers(version, build)


if __name__ == "__main__":
    sys.exit(not unittest.main(exit=False).result.wasSuccessful())

