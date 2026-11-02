---
trigger: always_on
---

EA_LAB entry rule (pointer only; grants no authority):

- Before EA_LAB work, record one exact canonical `origin/master` SHA and read `START_HERE.md`, `PROJECT_STATE.md`,
  `AGENTS.md` and the assigned task from that SHA.
- Interrupted, resumed or reassigned work follows `docs/workflows/CORE_SEAT_PROTOCOL_V8_20261102.md` §A1/§A4/§A4a.
  Read-only discovery comes first; write admission needs an owner assignment and a valid Lane Registry lease.
- Write only in a registered worktree from `origin/master`, never in the primary checkout.
- Without an assignment and a lease you are `ROLE_UNVERIFIED_READ_ONLY`.

For the full procedure, see `.agents/skills/ea-lab-workflow/SKILL.md`.
