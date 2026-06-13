#!/usr/bin/env python3
"""Placeholder Telegram command router for EA_LAB.

This file scaffolds the command surface only. It does not connect to Telegram,
does not place live trades, does not connect to a real account, and does not
deploy anything.
"""

from __future__ import annotations

import argparse
import json
import subprocess
import sys
import uuid
from dataclasses import dataclass, field
from pathlib import Path
from typing import Any

try:
    import yaml
except ImportError:  # pragma: no cover
    yaml = None


ROOT = Path(__file__).resolve().parents[1]
CONFIG_PATH = Path(__file__).with_name("config.yaml")


@dataclass
class Job:
    id: str
    command: str
    args: list[str]
    status: str = "queued"
    note: str = "placeholder only"


@dataclass
class QueueState:
    jobs: dict[str, Job] = field(default_factory=dict)


STATE = QueueState()


def load_config(path: Path = CONFIG_PATH) -> dict[str, Any]:
    if not path.exists():
        return {
            "config_loaded": False,
            "config_path": str(path),
            "note": "Copy config.example.yaml to config.yaml before real use.",
        }
    if yaml is None:
        config: dict[str, Any] = {}
        current_list_key: str | None = None
        for raw_line in path.read_text(encoding="utf-8").splitlines():
            line = raw_line.strip()
            if not line or line.startswith("#"):
                continue
            if line.startswith("- ") and current_list_key:
                value = line[2:].strip().strip('"').strip("'")
                try:
                    parsed_value: Any = int(value)
                except ValueError:
                    parsed_value = value
                config.setdefault(current_list_key, []).append(parsed_value)
                continue
            if ":" not in line:
                continue
            key, value = line.split(":", 1)
            key = key.strip()
            value = value.strip()
            current_list_key = None
            if not value:
                config[key] = []
                current_list_key = key
                continue
            value = value.strip('"').strip("'")
            if value.lower() == "true":
                config[key] = True
            elif value.lower() == "false":
                config[key] = False
            else:
                try:
                    config[key] = int(value)
                except ValueError:
                    config[key] = value
        config["config_parser"] = "simple_fallback"
    else:
        config = yaml.safe_load(path.read_text(encoding="utf-8")) or {}
        config["config_parser"] = "pyyaml"
    config["config_loaded"] = True
    return config


def is_allowed(config: dict[str, Any], user_id: int | None) -> bool:
    allowed = set(config.get("telegram_allowed_user_ids") or [])
    return user_id in allowed


def enqueue(command: str, args: list[str]) -> Job:
    job = Job(id=str(uuid.uuid4())[:8], command=command, args=args)
    STATE.jobs[job.id] = job
    return job


def run_placeholder_script(script_name: str, named_args: list[str]) -> dict[str, Any]:
    script_path = ROOT / "scripts" / script_name
    command = [
        "powershell",
        "-NoProfile",
        "-ExecutionPolicy",
        "Bypass",
        "-File",
        str(script_path),
        *named_args,
    ]
    result = subprocess.run(command, check=False, capture_output=True, text=True)
    return {
        "returncode": result.returncode,
        "stdout": result.stdout.strip(),
        "stderr": result.stderr.strip(),
    }


def cmd_status(config: dict[str, Any]) -> dict[str, Any]:
    mt5_path = config.get("mt5_terminal_path")
    return {
        "status": "placeholder router ready",
        "config_loaded": config.get("config_loaded", False),
        "queue_size": len(STATE.jobs),
        "mt5_path_configured": bool(mt5_path and Path(mt5_path).exists()),
        "safety": "no live trade execution, no lot automation, no deployment command",
        "environment_policy": "broker/server/account are run context only; not pass/fail unless P/L accounting fails",
    }


def cmd_list_ea() -> dict[str, Any]:
    projects_dir = ROOT / "ea_projects"
    projects = sorted(path.name for path in projects_dir.iterdir() if path.is_dir() and not path.name.startswith("_"))
    return {"projects": projects}


def cmd_run_backtest(project: str, symbol: str, timeframe: str) -> dict[str, Any]:
    set_file = ROOT / "ea_projects" / project / "set" / "default.set"
    job = enqueue("run_backtest.ps1", [project, symbol, timeframe, str(set_file)])
    result = run_placeholder_script(
        "run_backtest.ps1",
        ["-Project", project, "-Symbol", symbol, "-Timeframe", timeframe, "-SetFilePath", str(set_file)],
    )
    job.status = "done" if result["returncode"] == 0 else "failed"
    return {
        "job": job.__dict__,
        "result": result,
        "environment_validation": {
            "policy": "broker-agnostic and symbol-agnostic",
            "required_outputs": [
                "broker_server",
                "account_currency",
                "leverage",
                "symbol_name",
                "symbol_path",
                "tick_value",
                "tick_size",
                "contract_size",
                "profit_currency",
                "margin_currency",
                "tester_profit_valid",
            ],
            "fail_condition": "ENVIRONMENT_ACCOUNTING_FAIL only when closed deals exist, open/close prices differ, DEAL_PROFIT is zero for all or nearly all closed deals, and final balance/equity does not change",
            "warning_only": "BROKER_CONTEXT_DIFFERENT_FROM_USER_DEFAULT",
        },
    }


def cmd_import_manual_run(project: str, run_id: str) -> dict[str, Any]:
    job = enqueue("import_manual_run.ps1", [project, run_id])
    run_folder = ROOT / "ea_projects" / project / "backtest" / "manual_runs" / run_id
    return {
        "job": job.__dict__,
        "status": "placeholder only",
        "mode": "MANUAL_MT5_RUN_IMPORT",
        "run_folder": str(run_folder),
        "required_files": [
            "report.html",
            "trade_list.csv if available",
            "set_used.set if available",
            "run_context.yaml",
            "notes.txt",
        ],
        "script": str(ROOT / "scripts" / "import_manual_run.ps1"),
        "note": (
            "Telegram placeholder does not upload files yet. Run import_manual_run.ps1 "
            "with ReportPath, optional TradeListPath, optional SetPath, Symbol, Timeframe, "
            "StartDate, and EndDate. MT5 is not launched."
        ),
    }


def cmd_collect_reports(project: str, run_id: str, run_type: str) -> dict[str, Any]:
    if run_type not in {"baseline", "risk_cap_validation", "optimization", "oos"}:
        return {"error": "run_type must be baseline, risk_cap_validation, optimization, or oos"}
    job = enqueue("collect_mt5_reports.ps1", [project, run_id, run_type])
    result = run_placeholder_script(
        "collect_mt5_reports.ps1",
        ["-Project", project, "-RunId", run_id, "-RunType", run_type],
    )
    job.status = "done" if result["returncode"] == 0 else "failed"
    return {
        "job": job.__dict__,
        "result": result,
        "mode": "AUTO_MT5_REPORT_COLLECTOR",
        "note": "Collects manual MT5 artifacts only. It does not launch MT5 or run optimization.",
    }


def cmd_run_opt(project: str, mode: str) -> dict[str, Any]:
    if mode not in {"macro", "micro", "robustness"}:
        return {"error": "mode must be macro, micro, or robustness"}
    job = enqueue("run_optimization.ps1", [project, mode])
    result = run_placeholder_script("run_optimization.ps1", ["-Project", project, "-Mode", mode])
    job.status = "done" if result["returncode"] == 0 else "failed"
    return {"job": job.__dict__, "result": result}


def cmd_optimize(ea_name: str, symbol: str, timeframe: str, preset: str) -> dict[str, Any]:
    job = enqueue("optimization_plan", [ea_name, symbol, timeframe, preset])
    plan_folder = ROOT / "ea_projects" / ea_name / "optimization" / "plans"
    return {
        "job": job.__dict__,
        "status": "placeholder only",
        "output_folder": str(plan_folder),
        "note": "Scaffold for ea-optimization-orchestrator.md plan design. No MT5 optimization executed.",
    }


def cmd_analyze_opt(ea_name: str, report_path: str) -> dict[str, Any]:
    job = enqueue("optimization_analysis", [ea_name, report_path])
    analyzed_folder = ROOT / "ea_projects" / ea_name / "optimization" / "analyzed"
    return {
        "job": job.__dict__,
        "status": "placeholder only",
        "input_report_path": report_path,
        "output_folder": str(analyzed_folder),
        "note": "Would validate optimization CSV columns and analyze results in a future implementation.",
    }


def cmd_select_candidates(ea_name: str, top_arg: str = "TOP=5") -> dict[str, Any]:
    top = top_arg.split("=", 1)[1] if top_arg.upper().startswith("TOP=") else top_arg
    job = enqueue("candidate_selection", [ea_name, top])
    candidate_folder = ROOT / "ea_projects" / ea_name / "optimization" / "candidates"
    return {
        "job": job.__dict__,
        "status": "placeholder only",
        "top": top,
        "output_folder": str(candidate_folder),
        "note": "Would rank candidate sets and mark OOS-missing candidates as PRELIMINARY.",
    }


def cmd_run_oos(ea_name: str, set_ids_arg: str) -> dict[str, Any]:
    job = enqueue("oos_validation", [ea_name, set_ids_arg])
    oos_folder = ROOT / "ea_projects" / ea_name / "optimization" / "oos"
    return {
        "job": job.__dict__,
        "status": "placeholder only",
        "set_ids": set_ids_arg,
        "output_folder": str(oos_folder),
        "note": "Would run or register OOS validation before candidates can become APPROVED.",
    }


def cmd_compare_sets(ea_name: str, set_ids_arg: str) -> dict[str, Any]:
    job = enqueue("set_comparison", [ea_name, set_ids_arg])
    return {
        "job": job.__dict__,
        "status": "placeholder only",
        "set_ids": set_ids_arg,
        "note": "Would compare score, PF, DD, RF, OOS status, and cluster IDs.",
    }


def cmd_send_to_robustness(ea_name: str, set_ids_arg: str) -> dict[str, Any]:
    job = enqueue("robustness_handoff", [ea_name, set_ids_arg])
    handoff_folder = ROOT / "ea_projects" / ea_name / "handoff"
    return {
        "job": job.__dict__,
        "status": "placeholder only",
        "set_ids": set_ids_arg,
        "output_folder": str(handoff_folder),
        "safety_gate": "Only APPROVED OOS-passed candidates may be forwarded. PRELIMINARY candidates are refused by default.",
    }


def cmd_export(project: str) -> dict[str, Any]:
    job = enqueue("export_reports.ps1", [project])
    result = run_placeholder_script("export_reports.ps1", ["-Project", project])
    job.status = "done" if result["returncode"] == 0 else "failed"
    return {"job": job.__dict__, "result": result}


def cmd_summary(project: str) -> dict[str, Any]:
    folder = ROOT / "ea_projects" / project / "reports" / "latest"
    job = enqueue("summarize_results.py", [str(folder)])
    result = subprocess.run(
        [sys.executable, str(ROOT / "scripts" / "summarize_results.py"), str(folder)],
        check=False,
        capture_output=True,
        text=True,
    )
    job.status = "done" if result.returncode == 0 else "failed"
    return {
        "job": job.__dict__,
        "result": {
            "returncode": result.returncode,
            "stdout": result.stdout.strip(),
            "stderr": result.stderr.strip(),
        },
    }


def cmd_queue() -> dict[str, Any]:
    return {"jobs": [job.__dict__ for job in STATE.jobs.values()]}


def cmd_stop(job_id: str) -> dict[str, Any]:
    job = STATE.jobs.get(job_id)
    if not job:
        return {"error": "job not found", "job_id": job_id}
    job.status = "stop_requested"
    return {"job": job.__dict__, "note": "safe placeholder only"}


def cmd_approve(job_id: str) -> dict[str, Any]:
    job = STATE.jobs.get(job_id)
    if not job:
        return {"error": "job not found", "job_id": job_id}
    job.note = "manual approval placeholder recorded"
    return {"job": job.__dict__, "note": "no deployment action exists"}


def cmd_report_latest() -> dict[str, Any]:
    summaries = sorted(
        ROOT.glob("ea_projects/*/reports/latest/summary.json"),
        key=lambda path: path.stat().st_mtime,
        reverse=True,
    )
    return {"latest_summary": str(summaries[0]) if summaries else None}


def cmd_latest_report(project: str) -> dict[str, Any]:
    folder = ROOT / "ea_projects" / project / "reports" / "latest"
    files = sorted(
        [path for path in folder.glob("*") if path.is_file()],
        key=lambda path: path.stat().st_mtime,
        reverse=True,
    ) if folder.exists() else []
    return {
        "project": project,
        "latest_folder": str(folder),
        "latest_files": [str(path) for path in files[:10]],
    }


def cmd_latest_opt(project: str) -> dict[str, Any]:
    root = ROOT / "ea_projects" / project / "optimization" / "raw_results"
    folders = sorted(
        [path for path in root.glob("*") if path.is_dir()],
        key=lambda path: path.stat().st_mtime,
        reverse=True,
    ) if root.exists() else []
    return {
        "project": project,
        "latest_optimization_run": str(folders[0]) if folders else None,
        "raw_results_root": str(root),
    }


def route(command: str, args: list[str], config: dict[str, Any]) -> dict[str, Any]:
    if command == "/status":
        return cmd_status(config)
    if command == "/list_ea":
        return cmd_list_ea()
    if command == "/run_backtest" and len(args) == 3:
        return cmd_run_backtest(args[0], args[1], args[2])
    if command == "/import_manual_run" and len(args) == 2:
        return cmd_import_manual_run(args[0], args[1])
    if command == "/collect_reports" and len(args) == 3:
        return cmd_collect_reports(args[0], args[1], args[2])
    if command == "/run_opt" and len(args) == 2:
        return cmd_run_opt(args[0], args[1])
    if command == "/optimize" and len(args) == 4:
        return cmd_optimize(args[0], args[1], args[2], args[3])
    if command == "/analyze_opt" and len(args) == 2:
        return cmd_analyze_opt(args[0], args[1])
    if command == "/select_candidates" and len(args) in {1, 2}:
        return cmd_select_candidates(args[0], args[1] if len(args) == 2 else "TOP=5")
    if command == "/run_oos" and len(args) == 2:
        return cmd_run_oos(args[0], args[1])
    if command == "/compare_sets" and len(args) == 2:
        return cmd_compare_sets(args[0], args[1])
    if command == "/send_to_robustness" and len(args) == 2:
        return cmd_send_to_robustness(args[0], args[1])
    if command == "/export" and len(args) == 1:
        return cmd_export(args[0])
    if command == "/summary" and len(args) == 1:
        return cmd_summary(args[0])
    if command == "/queue":
        return cmd_queue()
    if command == "/stop" and len(args) == 1:
        return cmd_stop(args[0])
    if command == "/approve" and len(args) == 1:
        return cmd_approve(args[0])
    if command == "/report" and args == ["latest"]:
        return cmd_report_latest()
    if command == "/latest_report" and len(args) == 1:
        return cmd_latest_report(args[0])
    if command == "/latest_opt" and len(args) == 1:
        return cmd_latest_opt(args[0])
    return {
        "error": "unknown command or wrong arguments",
        "commands": [
            "/status",
            "/list_ea",
            "/run_backtest <project> <symbol> <timeframe>",
            "/import_manual_run <project> <run_id>",
            "/collect_reports <project> <run_id> <baseline|risk_cap_validation|optimization|oos>",
            "/run_opt <project> <macro|micro|robustness>",
            "/optimize EA_NAME SYMBOL TIMEFRAME PRESET",
            "/analyze_opt EA_NAME REPORT_PATH",
            "/select_candidates EA_NAME TOP=5",
            "/run_oos EA_NAME SET_IDS=...",
            "/compare_sets EA_NAME SET_IDS=...",
            "/send_to_robustness EA_NAME SET_IDS=...",
            "/export <project>",
            "/summary <project>",
            "/queue",
            "/stop <job_id>",
            "/approve <job_id>",
            "/report latest",
            "/latest_report <project>",
            "/latest_opt <project>",
        ],
    }


def main() -> int:
    parser = argparse.ArgumentParser(description="EA_LAB Telegram command scaffold.")
    parser.add_argument("command", nargs="?", default="/status")
    parser.add_argument("args", nargs="*")
    parser.add_argument("--user-id", type=int, default=None)
    parsed = parser.parse_args()

    config = load_config()
    if config.get("config_loaded") and parsed.user_id is not None and not is_allowed(config, parsed.user_id):
        print(json.dumps({"error": "unauthorized user"}, indent=2))
        return 1

    result = route(parsed.command, parsed.args, config)
    print(json.dumps(result, indent=2))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
