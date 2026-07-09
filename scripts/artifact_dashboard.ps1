# artifact_dashboard.ps1 - produce an artifact-ready (claude.ai) mobile view of LIVE_DASHBOARD.html
# Reuses the generated sections (no metric logic duplicated); swaps in token-based CSS that
# supports the claude.ai theme toggle (:root[data-theme]) which the desktop file does not need.
# Output: -OutFile (default scratchpad is per-session, so pass it explicitly from the session).
[CmdletBinding()]
param(
  [string]$InFile  = "D:\EA_LAB\portfolio\LIVE_DASHBOARD.html",
  [string]$OutFile = "$env:TEMP\ea_lab_dashboard_artifact.html"
)
$ErrorActionPreference = "Stop"
$html = [System.IO.File]::ReadAllText($InFile, [System.Text.Encoding]::UTF8)

# content = <h1> .. </body> minus wrapper; keep meta/legend/sections/footer
if ($html -notmatch '(?s)(<h1>.*?)</body>') { throw "unexpected LIVE_DASHBOARD.html structure" }
$content = $Matches[1]

$style = @'
<title>EA_LAB Port Monitor</title>
<style>
  :root {
    --paper:#F6F7F5; --card:#FFFFFF; --ink:#1B1E24; --ink-2:#5B6470; --line:#DDE1E4;
    --accent:#3E6B8F; --head:#EDF0F2;
    --good:#2E7D46; --warn:#9A6B14; --crit:#B3372E;
    --good-bg:#EBF4EE; --warn-bg:#F7F1E1; --crit-bg:#F9ECEA; --idle-bg:#F4F5F6; --unk-bg:#F0F0F2;
  }
  @media (prefers-color-scheme: dark) { :root {
    --paper:#16181D; --card:#1D2026; --ink:#E6E8EB; --ink-2:#9AA3AE; --line:#31353D;
    --accent:#7FA8C9; --head:#262A31;
    --good:#6FCF8B; --warn:#D9A94A; --crit:#EF8A80;
    --good-bg:#17301F; --warn-bg:#332B14; --crit-bg:#391B18; --idle-bg:#22252B; --unk-bg:#24242A;
  } }
  :root[data-theme="dark"] {
    --paper:#16181D; --card:#1D2026; --ink:#E6E8EB; --ink-2:#9AA3AE; --line:#31353D;
    --accent:#7FA8C9; --head:#262A31;
    --good:#6FCF8B; --warn:#D9A94A; --crit:#EF8A80;
    --good-bg:#17301F; --warn-bg:#332B14; --crit-bg:#391B18; --idle-bg:#22252B; --unk-bg:#24242A;
  }
  :root[data-theme="light"] {
    --paper:#F6F7F5; --card:#FFFFFF; --ink:#1B1E24; --ink-2:#5B6470; --line:#DDE1E4;
    --accent:#3E6B8F; --head:#EDF0F2;
    --good:#2E7D46; --warn:#9A6B14; --crit:#B3372E;
    --good-bg:#EBF4EE; --warn-bg:#F7F1E1; --crit-bg:#F9ECEA; --idle-bg:#F4F5F6; --unk-bg:#F0F0F2;
  }
  body { font-family: -apple-system, "Segoe UI", Roboto, sans-serif; background: var(--paper);
         color: var(--ink); margin: 0; padding: 12px; }
  h1 { font-size: 17px; margin: 4px 2px 6px; letter-spacing: .01em; }
  .meta { color: var(--ink-2); font-size: 11.5px; margin: 0 2px 14px; line-height: 1.5; }
  .meta code { font-family: inherit; background: none; color: inherit; }
  .card { background: var(--card); border: 1px solid var(--line); border-radius: 8px;
          padding: 10px 12px; margin-bottom: 12px; }
  .legend { font-size: 11.5px; color: var(--ink-2); line-height: 1.6; }
  .legend b { color: var(--ink); }
  .acct-head { font-size: 13px; line-height: 1.5; margin-bottom: 8px; color: var(--ink); }
  .acct-head b { color: var(--accent); font-size: 14px; }
  table { border-collapse: collapse; width: 100%; font-size: 12px;
          font-variant-numeric: tabular-nums; display: block; overflow-x: auto;
          -webkit-overflow-scrolling: touch; white-space: nowrap; }
  th, td { border: 1px solid var(--line); padding: 5px 8px; text-align: right; }
  th { background: var(--head); color: var(--ink-2); text-align: center; font-weight: 600;
       font-size: 11px; text-transform: uppercase; letter-spacing: .04em; }
  .name-cell, .label-cell { text-align: left; }
  .label-cell { color: var(--ink-2); }
  .status-cell { text-align: center; }
  .pos { color: var(--good); font-weight: 600; }
  .neg { color: var(--crit); font-weight: 600; }
  .neu { color: var(--ink-2); }
  tr.st-red    td { background: var(--crit-bg); }
  tr.st-yellow td { background: var(--warn-bg); }
  tr.st-green  td:first-child { background: var(--good-bg); }
  tr.st-white  td { background: var(--idle-bg); }
  tr.st-grey   td { background: var(--unk-bg); }
  .footer { color: var(--ink-2); font-size: 11px; margin-top: 14px; line-height: 1.5; }
</style>
'@

[System.IO.File]::WriteAllText($OutFile, $style + "`n" + $content, (New-Object System.Text.UTF8Encoding($false)))
Write-Host "wrote $OutFile"
