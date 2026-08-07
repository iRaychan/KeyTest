from __future__ import annotations

import hashlib
import importlib.util
import json
import tempfile
import unittest
from pathlib import Path

MODULE_PATH = Path(__file__).resolve().parents[1] / "tools" / "apply_v300.py"
spec = importlib.util.spec_from_file_location("apply_v300", MODULE_PATH)
module = importlib.util.module_from_spec(spec)
assert spec and spec.loader
spec.loader.exec_module(module)


def digest(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


INDEX_FIXTURE = """<!doctype html>
<html><head><title>KeySuite V2.27</title><link rel=\"manifest\" href=\"manifest.json\"><style>
.assembly-coupling-options{position:relative;z-index:2}
.assembly-coupling-resolved-note{margin:7px 0 0}
.assembly-coupling-bush-summary{position:relative;z-index:1}
</style></head><body>
<div class=\"auth-brand\">KeySuite<small>V2.32 Coupling</small></div>
<div class=\"brand\">KeySuite<small>Full Suite V2.32</small></div>
<div class=\"suite-version\">KeySuite V2.32</div>
<script src=\"config.js\"></script><script src=\"app.js?v=238\"></script>
<script src=\"assembly.js?v=238\"></script><script src=\"https://cdn.example/x.js\"></script>
</body></html>"""

SW_FIXTURE = """const CACHE='keysuite-v238';
const SHELL=['./','./index.html'];
"""


class V300PatcherTests(unittest.TestCase):
    def make_repo(self, root: Path) -> None:
        (root / "index.html").write_text(INDEX_FIXTURE, encoding="utf-8")
        (root / "manifest.json").write_text(json.dumps({"name": "KeySuite V2.38"}), encoding="utf-8")
        (root / "sw.js").write_text(SW_FIXTURE, encoding="utf-8")
        (root / "config.js").write_text("window.KEYSUITE_CONFIG={safe:true};\n", encoding="utf-8")

    def test_apply_and_idempotence(self) -> None:
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp)
            self.make_repo(root)
            config_hash = digest(root / "config.js")
            output = module.apply(root)
            self.assertTrue(output.is_file())
            index = (root / "index.html").read_text(encoding="utf-8")
            self.assertEqual(index.count(module.START_MARKER), 1)
            self.assertEqual(index.count(module.END_MARKER), 1)
            self.assertIn("grid-template-columns:repeat(3,minmax(0,1fr))", index)
            self.assertIn("@media(max-width:620px)", index)
            self.assertIn("KeySuite V3.00", index)
            self.assertIn('src="app.js?v=300"', index)
            self.assertIn('src="assembly.js?v=300"', index)
            self.assertIn('src="config.js"', index)
            self.assertIn('src="https://cdn.example/x.js"', index)
            self.assertEqual(digest(root / "config.js"), config_hash)
            self.assertIn("keysuite-v300", (root / "sw.js").read_text(encoding="utf-8"))
            self.assertEqual(json.loads((root / "manifest.json").read_text())["name"], "KeySuite V3.00")

            module.apply(root)
            second_index = (root / "index.html").read_text(encoding="utf-8")
            self.assertEqual(second_index.count(module.START_MARKER), 1)
            self.assertEqual(second_index.count(module.END_MARKER), 1)
            self.assertEqual(digest(root / "config.js"), config_hash)

    def test_missing_coupling_markers_stops_cleanly(self) -> None:
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp)
            self.make_repo(root)
            (root / "index.html").write_text("<html><style></style></html>", encoding="utf-8")
            original = digest(root / "index.html")
            with self.assertRaises(RuntimeError):
                module.apply(root)
            self.assertEqual(digest(root / "index.html"), original)


if __name__ == "__main__":
    unittest.main()
