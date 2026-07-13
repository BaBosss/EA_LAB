# FIXTURE TASKBOARD (pre-split state) -- REVIEW-block id-mismatch negative test

## ORDER-201 -- synthetic fixture order A -- `DONE(tester, 2026-01-01)`

Acceptance: none, this is a test fixture.

## ORDER-202 -- synthetic fixture order B -- `REVIEWED(tester, 2026-01-01) -- accepted`

Acceptance: none, this is a test fixture.

## REVIEW ORDER-201 -- `REVIEWED(tester, 2026-01-01)` -- fixture review of order A

## ORDER-206 -- synthetic fixture order F, mixed/partial stage -- `STAGE2-DONE(tester, 2026-01-01)` -- Stage 2 = รอ main session ตัดสินตามเกณฑ์

Acceptance: none, this is a test fixture. No REVIEW block anywhere references canonical
id 206 -- the REVIEW block below targets a DIFFERENT id (209) on purpose.

## REVIEW ORDER-209 -- `REVIEWED(tester, 2026-01-01)` -- fixture review of an unrelated order

## ORDER-203 -- synthetic fixture order C, still open -- `OPEN`

Acceptance: none, this is a test fixture.
