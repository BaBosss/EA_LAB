# Order-flow proxy preparation projection

This directory is a standalone, deterministic reporting seam for the Order Flow Proxy research plan. It emits one strict JSON projection and one static HTML preparation report. It is not a Monitor application, Registry parser, backtest parser, runtime observer, or status authority.

The source boundary is contract-locked to the accepted OFPR/OFPC manifest, source, provider seam, and strategy-card bytes. The CLI requires an exact 40-character commit that is also the checkout `HEAD`. Every locked working-tree input must equal the committed blob. Path escape, an outside-root symlink, a changed/missing input, an unexpected source hash, or a mismatched source identity fails closed. Git is used only for local object reads; the module has no fetch or network path.

Run with the repository portable Python:

```powershell
. .\scripts\use_python.ps1
Assert-PortablePython -Root D:\EA_LAB_CONTROL\w\ofp-view-0920 -Provision
$exactRef = git rev-parse HEAD
python -B tools/orderflow_proxy/research_presentation/cli.py `
  --repo-root D:\EA_LAB_CONTROL\w\ofp-view-0920 `
  --repo-ref $exactRef `
  --output-dir D:\EA_LAB_CONTROL\evidence\ofp-pipeline-20260920\view_author
```

The default outputs are `orderflow_preparation_projection.json` and `orderflow_preparation_report.html`. Existing outputs may be reused only when their bytes are identical; different existing bytes are refused.

An optional preparation-status observation is accepted only when all three observation arguments are supplied. Its file path must be relative to a declared observation root. The exact schema permits only source-bound `NOT_RUN`, zero executed cells, null performance, false authority claims, and false Monitor activation fields. An explicit `--observation-as-of-utc` must fall inside the observation's declared interval. Passing that check binds metadata; output freshness remains `NOT_ASSERTED` and never becomes runtime liveness.

Tests:

```powershell
. .\scripts\use_python.ps1
Assert-PortablePython -Root D:\EA_LAB_CONTROL\w\ofp-view-0920 -Provision
python -B -m unittest discover -s tools/orderflow_proxy/research_presentation/tests -v
```

The JSON is the direct integration surface. A later existing-Monitor owner may consume it only after serializer/UI ownership is free and a separate integration review passes. The HTML is a safe static preview rendered from that same projection: no JavaScript, external resource, link, Windows/UNC/file URL, login/account identifier, synthetic metric, or graph is emitted.
