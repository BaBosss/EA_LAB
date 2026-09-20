import copy
import hashlib
import importlib.util
import json
import sqlite3
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

REPORTER = Path(__file__).resolve().parents[1] / "usage_reporter.py"
SCHEMA_PATH = REPORTER.parent / "usage_report.schema.json"
SPEC = importlib.util.spec_from_file_location("usage_reporter", REPORTER)
reporter = importlib.util.module_from_spec(SPEC)
assert SPEC.loader
SPEC.loader.exec_module(reporter)
AS_OF = 2_000_000_000_000
HOUR = 3_600_000


def schema_target(rule, root):
    while "$ref" in rule:
        rule = root["$defs"][rule["$ref"].removeprefix("#/$defs/")]
    return rule


def schema_leaf_rules(rule, root, path="root"):
    rule = schema_target(rule, root)
    if rule.get("type") == "object":
        for name, child in sorted(rule.get("properties", {}).items()):
            yield from schema_leaf_rules(child, root, f"{path}.{name}")
        return
    if rule.get("type") == "array":
        yield from schema_leaf_rules(rule["items"], root, f"{path}[]")
        return
    if {"type", "const", "enum"}.intersection(rule):
        yield path, rule


def value_leaf_rules(value, rule, root, path=()):
    rule = schema_target(rule, root)
    if rule.get("type") == "object":
        for name, child in rule.get("properties", {}).items():
            if name in value:
                yield from value_leaf_rules(value[name], child, root, path + (name,))
        return
    if rule.get("type") == "array":
        for index, item in enumerate(value):
            yield from value_leaf_rules(item, rule["items"], root, path + (index,))
        return
    yield path, rule


def replace_at(value, path, replacement):
    cursor = value
    for part in path[:-1]:
        cursor = cursor[part]
    cursor[path[-1]] = replacement


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


class UsageReporterTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.home = Path(self.temp.name)
        db = sqlite3.connect(self.home / "state_5.sqlite")
        db.execute("CREATE TABLE threads(thread_id TEXT PRIMARY KEY,updated_at_ms INTEGER,tokens_used INTEGER,model TEXT,reasoning_effort TEXT,initial_prompt TEXT,parent_thread_id TEXT,agent_role TEXT)")
        db.executemany("INSERT INTO threads VALUES(?,?,?,?,?,?,?,?)", [
            ("a-heavy", AS_OF-100, 6_000_000, "gpt-5", "High", "abc", None, "root"),
            ("b-medium", AS_OF-200, 2_500_000, "gpt-5", "Medium", "hello", None, "primary"),
            ("c-sub", AS_OF-300, 500, "gpt-mini", "Medium", "x", "a-heavy", "worker"),
            ("d-old", AS_OF-25*HOUR, 1_000, "gpt-5", "High", "old", None, "root"),
            ("e-future", AS_OF+1, 9_000_000, "gpt-5", "High", "future", None, "root")])
        db.commit(); db.close()
        db = sqlite3.connect(self.home / "thread_history_1.sqlite")
        db.execute("CREATE TABLE thread_history(thread_id TEXT,item_type TEXT)")
        db.executemany("INSERT INTO thread_history VALUES(?,?)", [("a-heavy","user"),("a-heavy","assistant"),("b-medium","user"),("d-old","user")])
        db.commit(); db.close()

    def tearDown(self):
        self.temp.cleanup()

    def cli(self, *extra, home=None):
        return subprocess.run([sys.executable,str(REPORTER),"--hours","24","--as-of-ms",str(AS_OF),"--codex-home",str(home or self.home),*extra],capture_output=True,text=True)

    def test_complete_population_metadata_and_read_only_bytes(self):
        before = {p.name:digest(p) for p in self.home.glob("*.sqlite")}
        result = self.cli(); self.assertEqual(result.returncode,0,result.stderr)
        value = json.loads(result.stdout)
        self.assertEqual(value["population"],"RECENTLY_UPDATED_THREADS")
        self.assertEqual(value["thread_counts"],{"total":3,"top_level":2,"subagent":1})
        self.assertEqual(value["recently_updated_thread_lifetime_tokens_total"],8_500_500)
        self.assertEqual(value["token_counter_completeness"],"COMPLETE")
        self.assertEqual({x["value"]:x["count"] for x in value["reasoning_effort_counts"]},{"High":1,"Medium":2})
        self.assertEqual(value["initial_prompt_chars"],{"known_sum":9,"known_count":3,"unknown_count":0})
        self.assertEqual({x["item_type"]:x["count"] for x in value["thread_history_item_type_counts"]},{"assistant":1,"user":2})
        self.assertEqual(before,{p.name:digest(p) for p in self.home.glob("*.sqlite")})

    def test_null_is_partial_unknown_and_last(self):
        db=sqlite3.connect(self.home/"state_5.sqlite"); db.execute("UPDATE threads SET tokens_used=NULL WHERE thread_id='b-medium'"); db.commit(); db.close()
        value=json.loads(self.cli().stdout)
        self.assertEqual(value["token_counter_unknown_count"],1); self.assertEqual(value["token_counter_completeness"],"PARTIAL")
        self.assertIsNone(value["recently_updated_thread_lifetime_tokens_total"])
        last=value["heaviest_top_level_threads"][-1]; self.assertEqual(last["thread_id"],"b-medium"); self.assertIsNone(last["local_tokens"]); self.assertEqual(last["budget_signal"],"UNKNOWN")

    def test_lifetime_is_not_true_window_delta(self):
        db=sqlite3.connect(self.home/"state_5.sqlite"); db.execute("DELETE FROM threads")
        db.executemany("INSERT INTO threads VALUES(?,?,?,?,?,?,?,?)",[("old",AS_OF,1000,"gpt","Medium","",None,"root"),("new",AS_OF,100,"gpt","Medium","",None,"root")]); db.commit(); db.close()
        value=json.loads(self.cli().stdout)
        self.assertEqual(value["recently_updated_thread_lifetime_tokens_known_sum"],1100)
        self.assertEqual((1000-990)+100,110); self.assertIsNone(value["window_delta_tokens"])
        self.assertEqual(value["window_delta_status"],"UNAVAILABLE_NO_BOUNDED_COUNTER_DELTAS")

    def test_bad_hours_refused_before_database_access(self):
        for raw in ("-1","0","nan","inf","-inf"):
            result=subprocess.run([sys.executable,str(REPORTER),"--hours",raw,"--codex-home",str(self.home/"missing")],capture_output=True,text=True)
            self.assertEqual(result.returncode,2); self.assertIn("--hours must be finite and > 0",result.stderr); self.assertNotIn("database",result.stderr.lower())

    def test_very_large_finite_hours_remains_valid(self):
        result=subprocess.run([sys.executable,str(REPORTER),"--hours","1e308","--as-of-ms",str(AS_OF),"--codex-home",str(self.home)],capture_output=True,text=True)
        self.assertEqual(result.returncode,0,result.stderr)
        self.assertEqual(json.loads(result.stdout)["window_start_ms"],0)

    def test_bad_as_of_refused(self):
        for raw in ("0","-1","1.5","nan","inf"):
            result=subprocess.run([sys.executable,str(REPORTER),"--hours","1","--as-of-ms",raw,"--codex-home",str(self.home)],capture_output=True,text=True)
            self.assertEqual(result.returncode,2); self.assertIn("positive finite integer",result.stderr)

    def test_future_excluded_and_subagent_not_heaviest(self):
        value=json.loads(self.cli().stdout); ids=[x["thread_id"] for x in value["heaviest_top_level_threads"]]
        self.assertNotIn("e-future",ids); self.assertNotIn("c-sub",ids)

    def test_pinned_normal_economy_signals(self):
        normal=json.loads(self.cli("--mode","NORMAL").stdout); economy=json.loads(self.cli("--mode","ECONOMY").stdout)
        n={x["thread_id"]:x["budget_signal"] for x in normal["heaviest_top_level_threads"]}; e={x["thread_id"]:x["budget_signal"] for x in economy["heaviest_top_level_threads"]}
        self.assertEqual(n["b-medium"],"WITHIN_ADVISORY"); self.assertEqual(e["b-medium"],"ELEVATED"); self.assertEqual(n["a-heavy"],"HIGH")

    def test_closed_schema_and_runtime_unknown_refusal(self):
        value=reporter.build_report(self.home,24,AS_OF,"NORMAL"); bad=copy.deepcopy(value); bad["unknown"]=1
        with self.assertRaises(reporter.Refusal): reporter.validate_report(bad)
        schema=json.loads((REPORTER.parent/"usage_report.schema.json").read_text())
        self.assertFalse(schema["additionalProperties"])
        self.assertTrue(all(x["additionalProperties"] is False for x in schema["$defs"].values()))

    def test_missing_and_corrupt_fail_closed(self):
        missing=self.home/"missing"; missing.mkdir(); self.assertEqual(self.cli(home=missing).returncode,2)
        corrupt=self.home/"corrupt"; corrupt.mkdir(); (corrupt/"state_5.sqlite").write_bytes(b"bad"); (corrupt/"thread_history_1.sqlite").write_bytes(b"bad")
        result=self.cli(home=corrupt); self.assertEqual(result.returncode,2); self.assertIn("REFUSED",result.stderr)

    def test_create_only_output(self):
        out=self.home/"report.json"; first=self.cli("--out",str(out)); self.assertEqual(first.returncode,0,first.stderr); original=out.read_bytes()
        self.assertEqual(self.cli("--out",str(out)).returncode,2); self.assertEqual(out.read_bytes(),original)

    def test_no_alternate_policy_or_quota_savings_fields(self):
        help_text=subprocess.run([sys.executable,str(REPORTER),"--help"],capture_output=True,text=True).stdout.lower()
        self.assertNotIn("policy",help_text)
        value=json.loads(self.cli().stdout); self.assertIn("efficiency observations only",json.dumps(value).lower())
        self.assertTrue({"quota","billing","credits","plan_allowance","percent_savings","token_to_quota"}.isdisjoint(value))

    def test_v2_adversarial_probe_is_refused(self):
        value = reporter.build_report(self.home, 24, AS_OF, "NORMAL")
        value["policy_sha256"] = "z" * 64
        value["recently_updated_thread_lifetime_tokens_total"] = float(
            value["recently_updated_thread_lifetime_tokens_known_sum"])
        value["heaviest_top_level_threads"][0]["model"] = 7
        value["heaviest_top_level_threads"][0]["reasoning_effort"] = False
        with self.assertRaises(reporter.Refusal):
            reporter.validate_report(value)

    def test_bool_refused_for_every_populated_integer_or_number_leaf(self):
        schema = json.loads(SCHEMA_PATH.read_text(encoding="utf-8"))
        value = reporter.build_report(self.home, 24, AS_OF, "NORMAL")
        exercised = 0
        for path, rule in value_leaf_rules(value, schema, schema):
            declared = rule.get("type")
            types = declared if isinstance(declared, list) else [declared]
            if not {"integer", "number"}.intersection(types):
                continue
            exercised += 1
            bad = copy.deepcopy(value)
            replace_at(bad, path, True)
            with self.subTest(path=path), self.assertRaises(reporter.Refusal):
                reporter.validate_report(bad)
        self.assertGreater(exercised, 0)

    def test_min_length_strings_refuse_empty_and_non_string(self):
        schema = json.loads(SCHEMA_PATH.read_text(encoding="utf-8"))
        value = reporter.build_report(self.home, 24, AS_OF, "NORMAL")
        paths = [(path, rule) for path, rule in value_leaf_rules(value, schema, schema)
                 if rule.get("type") == "string" and rule.get("minLength") == 1]
        self.assertGreater(len(paths), 0)
        for path, _ in paths:
            for invalid in ("", 7):
                bad = copy.deepcopy(value)
                replace_at(bad, path, invalid)
                with self.subTest(path=path, invalid=invalid), self.assertRaises(reporter.Refusal):
                    reporter.validate_report(bad)

    def test_invalid_const_enum_pattern_and_nonfinite_number_refused(self):
        value = reporter.build_report(self.home, 24, AS_OF, "NORMAL")
        mutations = [
            ("schema_version", "wrong"),
            ("population", "wrong"),
            ("mode", "wrong"),
            ("token_counter_completeness", "wrong"),
            ("window_delta_status", "wrong"),
            ("policy_sha256", "z" * 64),
            ("hours", float("inf")),
        ]
        for key, invalid in mutations:
            bad = copy.deepcopy(value)
            bad[key] = invalid
            with self.subTest(key=key), self.assertRaises(reporter.Refusal):
                reporter.validate_report(bad)
        bad = copy.deepcopy(value)
        bad["heaviest_top_level_threads"][0]["budget_signal"] = "wrong"
        with self.assertRaises(reporter.Refusal):
            reporter.validate_report(bad)

    def test_nullable_integer_schema_fields_accept_only_integer_or_null(self):
        schema = json.loads(SCHEMA_PATH.read_text(encoding="utf-8"))
        value = reporter.build_report(self.home, 24, AS_OF, "NORMAL")
        nullable = [(path, rule) for path, rule in value_leaf_rules(value, schema, schema)
                    if rule.get("type") == ["integer", "null"]]
        self.assertGreater(len(nullable), 0)
        for path, _ in nullable:
            accepted = copy.deepcopy(value)
            replace_at(accepted, path, None)
            reporter.validate_schema_contract(accepted)
            for invalid in (0.0, True, "0", -1):
                bad = copy.deepcopy(value)
                replace_at(bad, path, invalid)
                with self.subTest(path=path, invalid=invalid), self.assertRaises(reporter.Refusal):
                    reporter.validate_schema_contract(bad)

    def test_nested_objects_refuse_unknown_and_missing_keys(self):
        value = reporter.build_report(self.home, 24, AS_OF, "NORMAL")
        objects = [
            value["thread_counts"],
            value["initial_prompt_chars"],
            value["model_counts"][0],
            value["reasoning_effort_counts"][0],
            value["thread_history_item_type_counts"][0],
            value["heaviest_top_level_threads"][0],
        ]
        for index, original in enumerate(objects):
            bad = copy.deepcopy(value)
            targets = [bad["thread_counts"], bad["initial_prompt_chars"], bad["model_counts"][0],
                       bad["reasoning_effort_counts"][0], bad["thread_history_item_type_counts"][0],
                       bad["heaviest_top_level_threads"][0]]
            targets[index]["unknown"] = 1
            with self.subTest(kind="unknown", index=index), self.assertRaises(reporter.Refusal):
                reporter.validate_report(bad)

            bad = copy.deepcopy(value)
            targets = [bad["thread_counts"], bad["initial_prompt_chars"], bad["model_counts"][0],
                       bad["reasoning_effort_counts"][0], bad["thread_history_item_type_counts"][0],
                       bad["heaviest_top_level_threads"][0]]
            del targets[index][next(iter(original))]
            with self.subTest(kind="missing", index=index), self.assertRaises(reporter.Refusal):
                reporter.validate_report(bad)

    def test_array_item_types_and_heaviest_limit_refused(self):
        value = reporter.build_report(self.home, 24, AS_OF, "NORMAL")
        for key in ("model_counts", "reasoning_effort_counts",
                    "thread_history_item_type_counts", "heaviest_top_level_threads"):
            bad = copy.deepcopy(value)
            bad[key] = ["wrong"]
            with self.subTest(key=key), self.assertRaises(reporter.Refusal):
                reporter.validate_report(bad)
        bad = copy.deepcopy(value)
        bad["heaviest_top_level_threads"] = bad["heaviest_top_level_threads"] * 6
        with self.assertRaises(reporter.Refusal):
            reporter.validate_report(bad)

    def test_schema_leaf_coverage_receipt(self):
        schema = json.loads(SCHEMA_PATH.read_text(encoding="utf-8"))
        supported = {"type", "const", "enum", "minLength", "minimum",
                     "exclusiveMinimum", "pattern"}
        leaves = list(schema_leaf_rules(schema, schema))
        uncovered = []
        coverage = {}
        for path, rule in leaves:
            constraints = sorted(supported.intersection(rule))
            coverage[path] = constraints
            if not constraints or set(rule).difference(supported):
                uncovered.append(path)
        receipt = {"schema_leaves": len(leaves), "covered": len(leaves) - len(uncovered),
                   "uncovered": sorted(uncovered), "shared_rule": "validate_schema_contract"}
        print("SCHEMA_COVERAGE_RECEIPT=" + json.dumps(receipt, sort_keys=True, separators=(",", ":")))
        self.assertEqual(uncovered, [])


if __name__ == "__main__": unittest.main()
