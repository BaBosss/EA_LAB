# EA_LAB Archive Rules

Goal: keep EA_LAB usable by humans. ACTIVE should show only current decision artifacts. ARCHIVE stores old evidence. SYSTEM stores scripts, rules, logs, and manifests.

## Top-Level Structure

| Folder | Purpose |
|---|---|
| `ACTIVE/` | Human-facing current state only |
| `ARCHIVE/` | Historical runs, old optimization outputs, duplicate reports |
| `SYSTEM/` | Cleanup rules, scripts, logs, manifests |
| `ea_projects/` | Working project sources and raw project workspace |

## ACTIVE Rules

ACTIVE keeps only:

- `latest_backtest.html`
- `latest_forward.html`
- `latest_oos.html`
- current candidate set files
- current candidate package folders
- source files needed for current candidate
- `latest_summary.md`

ACTIVE must not become a raw run dump.

## ARCHIVE Rules

Move these to ARCHIVE:

- rejected candidates,
- watch/failed candidate packages when `-IncludeRejected` is used,
- old optimization runs,
- raw optimization XML,
- old tester graphs,
- duplicate tester outputs,
- old run folders,
- old collected reports,
- old tester HTML/XLSX/PNG/CSV outputs.

## Preserve Rules

Never archive or delete current versions of:

- `source/`,
- current `.mq5` / `.ex5`,
- current candidate set files,
- current validated candidate packages,
- latest report aliases in ACTIVE,
- OOS/candidate acceptance notes,
- portfolio validation notes.

## Duplicate Rules

Duplicate reports are detected by SHA1 hash inside ARCHIVE. The script removes only exact binary duplicates after archiving. It does not remove files from `ea_projects` directly by duplicate hash unless they have already been moved to ARCHIVE.

## Rejected Candidate Rule

Rejected candidate folders are moved only when the script is run with `-IncludeRejected`.

Rejected name tokens:

- `REJECT`
- `FAILED`
- `WATCH`

## Execution Modes

Default:

```powershell
.\scripts\cleanup_project.ps1
```

Dry-run only. Shows intended operations.

Execute:

```powershell
.\scripts\cleanup_project.ps1 -ProjectName "Gold SMC continuous" -Execute
```

Copies ACTIVE snapshot, moves old artifacts to ARCHIVE, and removes exact duplicates inside ARCHIVE.

## Naming Convention

Archive path:

```text
ARCHIVE/projects/<project>/<yyyyMMdd_HHmmss>/
```

Active path:

```text
ACTIVE/projects/<project>/
```

