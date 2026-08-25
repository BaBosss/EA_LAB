[CmdletBinding()]
param(
  [Parameter(Mandatory = $true)][string]$SourcePath,
  [Parameter(Mandatory = $true)][string]$PresetPath,
  [Parameter(Mandatory = $true)][string]$ReportPath,
  [Parameter(Mandatory = $true)][string]$SourceCommit,
  [string]$OutputRoot = '',
  [string]$PythonExe = '',
  [string]$WindowClass = 'COMMON_VALIDATION',
  [string]$TesterModel = 'MT5_MODEL_4_REAL_TICKS'
)

$ErrorActionPreference = 'Stop'
$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
if (-not $OutputRoot) { $OutputRoot = Join-Path $RepoRoot 'factory\vnext\pilots' }
$SourcePath = (Resolve-Path -LiteralPath $SourcePath).Path
$PresetPath = (Resolve-Path -LiteralPath $PresetPath).Path
$ReportPath = (Resolve-Path -LiteralPath $ReportPath).Path
$OutputRoot = [IO.Path]::GetFullPath($OutputRoot)

if ([string]::IsNullOrWhiteSpace($PythonExe)) {
  . (Join-Path $RepoRoot 'scripts\use_python.ps1')
  $PythonExe = Assert-PortablePython -Root $RepoRoot
}
if (-not (Test-Path -LiteralPath $PythonExe -PathType Leaf)) { throw "PythonExe not found: $PythonExe" }

$cfg = [ordered]@{
  repo_root = $RepoRoot
  source_path = $SourcePath
  preset_path = $PresetPath
  report_path = $ReportPath
  source_commit = $SourceCommit
  window_class = $WindowClass
  tester_model = $TesterModel
  output_root = $OutputRoot
}
$cfgPath = Join-Path $env:TEMP ("factory_vnext_pilot_cfg_{0}.json" -f ([guid]::NewGuid().ToString('N')))
$pyPath = Join-Path $env:TEMP ("factory_vnext_pilot_{0}.py" -f ([guid]::NewGuid().ToString('N')))
[IO.File]::WriteAllText($cfgPath, ($cfg | ConvertTo-Json -Depth 5 -Compress), (New-Object System.Text.UTF8Encoding($true)))

$py = @'
import hashlib, json, os, re, shutil, subprocess, sys
from pathlib import Path

def die(msg, code=1):
    print(msg)
    sys.exit(code)

cfg = json.loads(Path(sys.argv[1]).read_text(encoding="utf-8-sig"))
sys.path.insert(0, cfg["repo_root"])
from _triage.factory_vnext.pilot import build_supertrend_report_pilot, validate_pilot_record, write_pilot_artifacts
from _triage.factory_vnext.supertrend_adapter import SOURCE_REL_PATH, PRESET_REL_PATH
for key in ("source_path", "preset_path", "report_path"):
    if not os.path.isfile(cfg[key]):
        die(f"BLOCKED missing {key}: {cfg[key]}", 2)
try:
    subprocess.run(["git", "-C", cfg["repo_root"], "rev-parse", "--verify", "--quiet", cfg["source_commit"]], check=True, capture_output=True, text=True)
except Exception:
    die(f"BLOCKED invalid SourceCommit: {cfg['source_commit']}", 2)

def git_show(pathspec):
    proc = subprocess.run(["git", "-C", cfg["repo_root"], "show", f"{cfg['source_commit']}:{pathspec}"], check=True, capture_output=True)
    return proc.stdout

def sha(data):
    return hashlib.sha256(data).hexdigest()

tracked_source = git_show(SOURCE_REL_PATH)
tracked_preset = git_show(PRESET_REL_PATH)
if sha(open(cfg["source_path"], "rb").read()) != sha(tracked_source):
    die("BLOCKED source bytes do not match SourceCommit", 2)
if sha(open(cfg["preset_path"], "rb").read()) != sha(tracked_preset):
    die("BLOCKED preset bytes do not match SourceCommit", 2)

work_root = Path(cfg["repo_root"]) / ".tmp" / "factory_vnext_runner" / Path(os.urandom(8).hex())
work_root.mkdir(parents=True, exist_ok=False)
stage_source = work_root / Path(cfg["source_path"]).name
stage_preset = work_root / Path(cfg["preset_path"]).name
stage_report = work_root / Path(cfg["report_path"]).name
for src, dst in ((cfg["source_path"], stage_source), (cfg["preset_path"], stage_preset), (cfg["report_path"], stage_report)):
    with open(src, "rb") as rf, open(dst, "wb") as wf:
        wf.write(rf.read())

try:
    record = build_supertrend_report_pilot(
        repo_root=cfg["repo_root"],
        report_path=str(stage_report),
        source_commit=cfg["source_commit"],
        window_class=cfg["window_class"],
        tester_model=cfg["tester_model"],
        source_path=str(stage_source),
        preset_path=str(stage_preset),
        report_root=str(work_root),
    )
except Exception as exc:
    die(f"BLOCKED {exc}", 3)

canonical_refs = {
    sha(tracked_source): SOURCE_REL_PATH.replace("\\", "/"),
    sha(tracked_preset): PRESET_REL_PATH.replace("\\", "/"),
}
seen_refs = set()
for ref in record["RunManifest"].get("artifacts", []):
    canonical_path = canonical_refs.get(ref.get("sha256"))
    if canonical_path:
        ref["path"] = canonical_path
        seen_refs.add(ref["sha256"])
if seen_refs != set(canonical_refs):
    die("BLOCKED source/preset provenance normalization mismatch", 3)
validate_pilot_record(record)

pilot_id = record["PilotID"]
run_id = record["RunManifest"]["RunID"]
output_root = Path(cfg["output_root"])
pilot_dir = output_root / pilot_id
staging = output_root / (pilot_id + ".staging")
staging.mkdir(parents=True, exist_ok=True)
write_pilot_artifacts(record, str(staging))

def sha_path(path):
    h = hashlib.sha256()
    with open(path, "rb") as fh:
        for chunk in iter(lambda: fh.read(1024 * 1024), b""):
            h.update(chunk)
    return h.hexdigest()

manifest = staging / "pilot_manifest.json"
index = staging / "artifact_index.json"
report = staging / "report.html"
for path in (manifest, index, report):
    text = path.read_text(encoding="utf-8")
    if re.search(r"[A-Za-z]:\\", text) or "file://" in text.lower():
        die(f"BLOCKED absolute path leak in {path.name}", 4)

if pilot_dir.exists():
    expected = {}
    current = {}
    for name in ("pilot_manifest.json", "artifact_index.json", "report.html"):
        src = staging / name
        dst = pilot_dir / name
        expected[name] = {"sha256": sha_path(src), "bytes": src.stat().st_size}
        if not dst.is_file():
            die(f"BLOCKED collision mismatch missing {name}", 5)
        current[name] = {"sha256": sha_path(dst), "bytes": dst.stat().st_size}
    if current != expected:
        changed = [name for name in expected if current.get(name) != expected.get(name)]
        die("BLOCKED collision mismatch refuses overwrite: " + ",".join(changed), 5)
else:
    pilot_dir.mkdir(parents=True, exist_ok=False)
    for name in ("pilot_manifest.json", "artifact_index.json", "report.html"):
        (pilot_dir / name).write_bytes((staging / name).read_bytes())

# write_pilot_artifacts already binds exact manifest/report bytes in artifact_index.json.
# Preserve artifact_index.json verbatim so identical reruns remain byte-idempotent.
shutil.rmtree(staging, ignore_errors=True)

print(json.dumps({"status": "PASS", "PilotID": pilot_id, "RunID": run_id, "ReportPath": str(pilot_dir / "report.html")}, sort_keys=True))
'@

[IO.File]::WriteAllText($pyPath, $py, (New-Object System.Text.UTF8Encoding($true)))
try {
  $result = & $PythonExe $pyPath $cfgPath
  if ($LASTEXITCODE -ne 0) {
    $detail = (($result | ForEach-Object { [string]$_ }) -join "`n").Trim()
    if ($detail) { throw "run_factory_vnext_pilot failed exit=$LASTEXITCODE :: $detail" }
    throw "run_factory_vnext_pilot failed exit=$LASTEXITCODE"
  }
  Write-Host $result
} finally {
  $runnerTmp = Join-Path (Join-Path $RepoRoot '.tmp') 'factory_vnext_runner'
  if (Test-Path -LiteralPath $runnerTmp) {
    Remove-Item -LiteralPath $runnerTmp -Recurse -Force -ErrorAction SilentlyContinue
  }
  Remove-Item -LiteralPath $cfgPath, $pyPath -Force -ErrorAction SilentlyContinue
}
