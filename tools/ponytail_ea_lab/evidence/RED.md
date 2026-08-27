# Ponytail EA_LAB Module — RED Evidence

A genuine RED was observed before `ponytail_policy.ps1` existed.

Command:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File tools/ponytail_ea_lab/tests/run_tests.ps1
```

Observed failure:

```text
The argument '...\tools\ponytail_ea_lab\ponytail_policy.ps1' to the -File parameter does not exist.
RED_EXIT=1
```

This RED is relevant: the focused test suite depended on the missing policy implementation rather than on an unrelated environment failure.

After implementation, a second defect was reproduced: a contract missing `requested_mode` escaped as a PowerShell `PropertyNotFoundException` under StrictMode instead of returning a structured fail-closed result. The bounded repair added optional-property access plus a regression case.