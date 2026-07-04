@echo off
REM ============================================================
REM go_agents.cmd - one-click: send Codex to work the taskboard
REM  Usage: double-click, or run "go_agents" in any terminal.
REM  Codex reads AGENTS.md rules, claims OPEN orders in
REM  AGENT_TASKBOARD.md, executes, appends raw results, commits.
REM  (If codex asks for approvals, re-run with your usual flags,
REM   e.g.:  codex exec --full-auto "..."  )
REM ============================================================
cd /d D:\EA_LAB
codex exec --full-auto "You are Codex working in D:\EA_LAB. Read D:\EA_LAB\AGENTS.md (rules) then D:\EA_LAB\AGENT_TASKBOARD.md. Execute every order with status OPEN that matches your role, one at a time in numeric order: set status CLAIMED, run the commands exactly as written, append raw results under the order, set status DONE, then git commit with a message starting with [codex]. Follow every rule in AGENTS.md strictly: no verdicts, no editing VISION/PROJECT_STATE section 3/scorecard verdicts, one MT5 job at a time, report raw numbers only. If blocked, write BLOCKED with the question and move to the next order. Stop when no OPEN orders remain."
pause
