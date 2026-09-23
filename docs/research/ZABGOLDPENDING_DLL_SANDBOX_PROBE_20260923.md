# ZABgoldpending — owner-approved DLL AppContainer semantic probe — 2026-09-23

Status: `PREREGISTERED_NOT_RUN / OWNER_APPROVED_SANDBOXED_DLL_SEMANTIC_ONLY`.

The owner explicitly approved continuing past the prior DLL trust blocker. This approval is implemented only as an **AppContainer-isolated, no-network DLL-enabled semantic probe**. It does not authorize enabling DLL imports on the host MT5 installation, performance testing, optimization, HOLDOUT, deployment, runtime or LIVE trading.

## Isolation acceptance before MT5

The dedicated Windows AppContainer self-test passed all required controls:

- sandbox-local write: `OK`;
- read of the EA_LAB repo outside the explicitly granted sandbox root: `BLOCKED`;
- outbound TCP network access: `BLOCKED`;
- no AppContainer network capability is granted.

DLL permission will be enabled only in the sandbox terminal configuration. Host MT5 settings remain unchanged.

## Semantic contract

The already accepted A/B/C rule remains unchanged:

- A_OWNER: `Risk_Percent=1.0`, `Fixed_Lot_Size=0.1`
- B_FIXED_ONLY: `Risk_Percent=1.0`, `Fixed_Lot_Size=0.2`
- C_RISK_ONLY: `Risk_Percent=2.0`, `Fixed_Lot_Size=0.1`

Frozen carrier: exact EX5 SHA256 `f75e6d11f298765521d0bbcb7ce37c0e2fdacec3136315dd48047ee2249c9c90`, `XAUUSD M5`, Model-1, MAIN subwindow `2023-01-01..2023-03-31`, deposit `10000 USD`, leverage `1:100`, all other 10 inputs unchanged.

Admissible evidence is only first-entry timestamp/side/volume and init/dependency errors. PF, net, DD, ending balance, win rate, exit outcomes and later trade path are forbidden evidence.

Decision remains fail-closed: same first signal is mandatory; any init failure, no first entry, signal mismatch, both axes affecting volume, or neither axis affecting volume => `UNKNOWN`.

No performance MAIN/BWD execution follows automatically even if precedence resolves.