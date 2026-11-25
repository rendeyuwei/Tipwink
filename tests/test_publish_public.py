from importlib.machinery import SourceFileLoader
from importlib.util import module_from_spec, spec_from_loader
from pathlib import Path
import tempfile
import unittest

loader = SourceFileLoader("promotion", str(Path(__file__).resolve().parents[1] / "scripts/publish-public"))
spec = spec_from_loader(loader.name, loader)
promotion = module_from_spec(spec)
loader.exec_module(promotion)


class PromotionTests(unittest.TestCase):
    def setUp(self):
        self.receipt = dict(zip_sha256="a" * 64, source_commit="b" * 40, version="0.7.1",
                            build=16, from_version="0.7.0", from_build=15, evidence="Native smoke record")
        self.receipt.update(dict.fromkeys(promotion.TESTS, True))

    def validate(self, previous):
        promotion.valid_receipt(self.receipt, "a" * 64, "0.7.1", 16, previous, "b" * 40)

    def test_bootstrap_and_normal_receipt(self):
        self.validate(None)
        self.validate(("0.7.0", 15))

    def test_wrong_baseline_is_rejected(self):
        with self.assertRaises(ValueError):
            self.validate(("0.6.4", 13))

    def test_receipt_must_match_exact_candidate(self):
        self.receipt["zip_sha256"] = "c" * 64
        with self.assertRaises(ValueError):
            self.validate(None)

    def test_missing_install_evidence_is_rejected(self):
        self.receipt.pop("install")
        with self.assertRaises(ValueError):
            self.validate(None)

    def test_feed_read_rejects_more_than_one_item(self):
        with tempfile.TemporaryDirectory() as tmp:
            path = Path(tmp) / "feed.xml"
            path.write_text("<rss><channel><item/><item/></channel></rss>")
            with self.assertRaises(ValueError):
                promotion.cast_version(path)
