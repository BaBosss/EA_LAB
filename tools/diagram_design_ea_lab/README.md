# EA_LAB Diagram Design Module

This module produces deterministic, self-contained offline HTML workflow diagrams from `workflow_manifest.json`.

## Installation pin

The renderer is an EA_LAB wrapper around [`diagram-design`](https://github.com/cathrynlavery/diagram-design) pinned at `4faae6696c2953b59dee2b89ad89c688f80c3a67` (skill version 2.6). Installation and linked-skill state can be inspected without changing it:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File tools\diagram_design_ea_lab\Invoke-DiagramDesign.ps1 -Action Status
```

## Use

```powershell
# List profiles and emit a stable rendering brief.
powershell -NoProfile -ExecutionPolicy Bypass -File tools\diagram_design_ea_lab\Invoke-DiagramDesign.ps1 -Action List
powershell -NoProfile -ExecutionPolicy Bypass -File tools\diagram_design_ea_lab\Invoke-DiagramDesign.ps1 -Action Prompt -Profile toolchain-architecture

# Regenerate every baseline HTML file declared in the manifest.
powershell -NoProfile -ExecutionPolicy Bypass -File tools\diagram_design_ea_lab\Build-BaselineDiagrams.ps1

# Run focused acceptance.
powershell -NoProfile -ExecutionPolicy Bypass -File tools\diagram_design_ea_lab\tests\run_tests.ps1
```

Generated outputs are under `docs/diagrams/`. They embed CSS and SVG and use no CDN, web font, script, or external asset.

## Authority boundary

This is visual documentation only. Every output carries `VISUAL_ONLY_NO_AUTHORITY`. It never grants runtime, Git, governance, trading, deployment, LIVE promotion, risk/default-change, or owner-attestation authority. Source artifacts and owner-approved governance remain authoritative.
