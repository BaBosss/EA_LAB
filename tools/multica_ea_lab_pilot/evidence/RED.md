# TDD RED evidence

Focused command:
`powershell -NoProfile -ExecutionPolicy Bypass -File tools\multica_ea_lab_pilot\tests\run_tests.ps1 -Integration`

Observed before implementation:
`Import-Module ... MulticaPilot.psm1 ... no valid module file was found`

Classification: expected RED. The test contract existed before the implementation module.
