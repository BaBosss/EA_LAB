# ZABgoldpending — DLL AppContainer semantic probe result — 2026-09-23

Status: `SEMANTICS_UNRESOLVED / C_ENVIRONMENT_DEPENDENCY_SAFE_DLL_SANDBOX_NO_TESTER_ACCOUNT_CONTEXT / READY_FOR_TEST=false`.

Authority: `OWNER_APPROVED_SANDBOXED_DLL_SEMANTIC_ONLY`. No performance, optimization, HOLDOUT, deployment, runtime or LIVE authority is created.

## Security boundary proved first

The Windows AppContainer lowbox passed the required isolation checks before the opaque EX5 was given DLL permission:

- sandbox-local write: `OK`;
- read of EA_LAB repo outside the granted sandbox root: `BLOCKED`;
- outbound network: `BLOCKED`;
- minimal `registryRead` follow-up: registry read `OK`, while external repo read and network remained `BLOCKED`.

DLL permission was enabled only in the sandbox terminal/config. The host MT5 DLL setting was not changed and no host MT5 process was used.

## Execution outcome

The exact selected EX5 remained SHA256 `f75e6d11f298765521d0bbcb7ce37c0e2fdacec3136315dd48047ee2249c9c90`, MT5 build `6182`.

Three bounded environment attempts were made:

1. `A_OWNER` in zero-capability AppContainer: MT5 logged `Accounts deleted due security reason`, then `tester not started because the account is not specified`; no report.
2. no-account chart-init probe in the same no-network lowbox: chart context could not load and no EA-init semantic evidence was produced.
3. `A_OWNER` with only `registryRead` capability added: external-file and network isolation still passed, but MT5 again deleted the copied account context before tester start.

After the last attempt the sandbox `accounts.dat` was absent. No reusable local startup `Password=` credential was found in the primary MT5 installation or current EA_LAB worktree. No credential value was copied into Git.

## Semantic decision

The canonical A/B/C contract requires a valid A first-entry signal before B/C comparisons. A never reached tester execution in the safe sandbox, so:

- `B_FIXED_ONLY` was not run;
- `C_RISK_ONLY` was not run;
- first-entry evidence = none;
- `Risk_Percent` vs `Fixed_Lot_Size` precedence remains `UNKNOWN`;
- `READY_FOR_TEST=false` remains binding.

This is an environment/account-context blocker, not a strategy failure and not evidence for either money mode.

No PF, net, DD, win rate, exit result or later trade path was consumed. HOLDOUT `2026H1` remains unspent and optimization remains unauthorized.

## Next lawful gate

Use a disposable Windows VM/sandbox where MT5 can be freshly authenticated **before** the opaque EX5 is introduced, then disconnect network and only afterwards enable/import the DLL-required EA for the same A/B/C first-entry semantic probe. Alternatively obtain a trusted DLL/source/dependency path.

Do not weaken the current host isolation or enable DLL imports for the opaque EX5 on the main Windows environment.

External execution receipt: `D:/EA_LAB_CONTROL/evidence/zabgoldpending-mm-semantic-20260923/DLL_SANDBOX_EXECUTION_RECEIPT.json`.