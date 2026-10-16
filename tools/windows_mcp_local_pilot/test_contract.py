"""Fail-closed static contract tests; no subprocess, network, or desktop access."""
from pathlib import Path
import tomllib
import unittest

ROOT = Path(__file__).resolve().parent
EXPECTED = "windows-mcp==0.8.8"


class PilotConfigTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.raw = (ROOT / "codex_example.toml").read_text(encoding="utf-8-sig")
        cls.doc = tomllib.loads(cls.raw)
        cls.entry = cls.doc["mcp_servers"]["ea_lab_windows_display_pilot"]

    def test_disabled_by_default(self):
        self.assertIs(self.entry["enabled"], False)

    def test_pinned_version_and_allowlist(self):
        args = self.entry["args"]
        self.assertIn(EXPECTED, args)
        self.assertEqual(args[args.index("--tools") + 1], "DisplayInventory")
        self.assertEqual(args[args.index("--transport") + 1], "stdio")
        self.assertNotIn("--exclude-tools", args)
        self.assertNotIn("install", args)

    def test_no_listener_or_unsafe_tools(self):
        args = self.entry["args"]
        self.assertNotIn("--host", args)
        self.assertNotIn("--port", args)
        self.assertNotIn("PowerShell", args)
        self.assertNotIn("FileSystem", args)
        self.assertNotIn("Registry", args)
        self.assertNotIn("Click", args)

    def test_opt_out_telemetry(self):
        env = self.entry["env"]
        self.assertEqual(env["ANONYMIZED_TELEMETRY"], "false")
        self.assertEqual(env["POSTHOG_API_KEY"], "")
        self.assertEqual(env["WINDOWS_MCP_TOOLS"], "DisplayInventory")

    def test_identity_guard(self):
        self.assertIn("uv.exe", self.entry["command"].lower())
        self.assertNotIn("EA_LAB", self.entry["command"])
        self.assertEqual(self.entry["args"].count("--tools"), 1)

    def test_readme_source_label(self):
        readme = (ROOT / "README.md").read_text(encoding="utf-8-sig")
        self.assertIn("SOURCE-ONLY", readme)
        self.assertIn(EXPECTED, readme)
        self.assertIn("Main CT", readme)


if __name__ == "__main__":
    unittest.main(verbosity=2)
