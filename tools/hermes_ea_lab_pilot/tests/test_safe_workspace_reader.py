from __future__ import annotations

import importlib.util
import tempfile
import unittest
from pathlib import Path


SCRIPT = Path(__file__).resolve().parents[1] / "scripts" / "safe_workspace_reader_mcp.py"
spec = importlib.util.spec_from_file_location("safe_workspace_reader_mcp", SCRIPT)
module = importlib.util.module_from_spec(spec)
assert spec and spec.loader
spec.loader.exec_module(module)


class SafeWorkspaceReaderTests(unittest.TestCase):
    def setUp(self) -> None:
        self.tmp = tempfile.TemporaryDirectory()
        self.outside = tempfile.TemporaryDirectory()
        self.root = Path(self.tmp.name).resolve()
        self.outside_root = Path(self.outside.name).resolve()
        (self.root / "a.txt").write_text("alpha\nStepATR=0.30\n", encoding="utf-8")
        (self.root / "nested").mkdir()
        (self.root / "nested" / "b.txt").write_text("beta\nFastMA=20\n", encoding="utf-8")
        (self.outside_root / "secret.txt").write_text("OUTSIDE_SECRET", encoding="utf-8")

    def tearDown(self) -> None:
        self.tmp.cleanup()
        self.outside.cleanup()

    def test_observe_can_read_safe_workspace_file(self) -> None:
        output = module.read_text_impl(self.root, "a.txt", 1, 10)
        self.assertIn("StepATR=0.30", output)

    def test_observe_can_read_multiple_canonical_files(self) -> None:
        first = module.read_text_impl(self.root, "a.txt", 1, 10)
        second = module.read_text_impl(self.root, "nested/b.txt", 1, 10)
        self.assertIn("StepATR=0.30", first)
        self.assertIn("FastMA=20", second)
        hits = module.search_text_impl(self.root, "FastMA", max_results=10)
        self.assertIn("nested/b.txt:2: FastMA=20", hits)

    def test_observe_search_accepts_direct_file_path(self) -> None:
        hits = module.search_text_impl(self.root, "FastMA", path="nested/b.txt", max_results=10)
        self.assertEqual(hits, "nested/b.txt:2: FastMA=20")

    def test_observe_rejects_path_escape(self) -> None:
        with self.assertRaisesRegex(ValueError, "absolute paths are denied"):
            module.read_text_impl(self.root, str(self.outside_root / "secret.txt"))
        relative_escape = Path("..") / self.outside_root.name / "secret.txt"
        with self.assertRaises((ValueError, FileNotFoundError)):
            module.read_text_impl(self.root, relative_escape.as_posix())

    def test_observe_rejects_write_surface(self) -> None:
        import anyio

        async def names() -> list[str]:
            return [tool.name for tool in await module.create_server(self.root).list_tools()]

        tools = anyio.run(names)
        self.assertEqual(sorted(tools), ["list_files", "read_text", "search_text", "sha256_file"])
        for prohibited in ("write", "delete", "remove", "move", "copy", "terminal", "exec", "git"):
            self.assertFalse(any(prohibited in name.lower() for name in tools), tools)

    def test_observe_sha256_is_bounded_to_workspace(self) -> None:
        digest = module.sha256_file_impl(self.root, "a.txt")
        self.assertEqual(len(digest), 64)
        with self.assertRaisesRegex(ValueError, "absolute paths are denied"):
            module.sha256_file_impl(self.root, str(self.outside_root / "secret.txt"))


if __name__ == "__main__":
    unittest.main(verbosity=2)
