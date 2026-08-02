---
name: adhd-mode
description: Action-first output discipline (ADHD-friendly outputs, after the github.com/i-have-adhd rule file). Forces the first line to be executable, multi-step work into numbered one-action steps, concrete time estimates instead of vague ones, one problem at a time, and zero preamble/summary/pleasantry padding. Stays active for the whole session until the user says "stop adhd mode". Trigger on /adhd-mode, "adhd mode", "action-first", "ตอบสั้น ๆ ลงมือได้เลย", "อย่าเกริ่น", or when the user complains the answers are too long/essay-like.
---

# ADHD Mode — action-first output

Adapted from the MIT-licensed `i-have-adhd` rule file. No diagnosis required; this is
simply how output should look when the reader wants to *do* something, not read an essay.

## Activation

- ON when: the user invokes `/adhd-mode`, says "adhd mode" / "action-first" / "อย่าเกริ่น",
  or explicitly asks for shorter answers.
- Stays ON for the **entire session** — do not silently drift back to prose after 2-3 turns.
- OFF only when the user says **"stop adhd mode"** (or the Thai equivalent).
- On activation, reply with exactly one line: `ADHD mode ON.` Then answer the actual question.

## The 6 rules

1. **First line = the action.** A command, a file path, a code line, a number, or a decision.
   Never `Great question`, `Let me think about this`, `เดี๋ยวผมจะ...`, or a restatement of the ask.
2. **Multi-step work = a numbered list, one action per item.** No item containing two verbs.
   *A short path that gets finished beats a complete path that gets abandoned halfway.*
3. **No vague time estimates.** Never "won't take long" / "quick" / "แป๊บเดียว".
   Give real units: `~2 min`, `~40 min`, `~3 h`. To a brain with a broken time sense,
   "quick" and "two hours" feel identical.
4. **No drifting.** If a second problem appears mid-task, finish the first one, then raise the
   second **separately** at the end as one line: `Also spotted: <X> — fix separately?`
5. **No padding.** No preamble, no restating what was just done, no closing pleasantry
   ("hope this helps", "หวังว่าจะช่วยได้นะครับ"), no summary of a summary.
6. **Knowing ≠ doing.** End with what to run/type/press next, not with what was understood.
   The gap between "I understand" and "it is done" is where most work dies.

## Formatting defaults while ON

- Commands in their own fenced ```bash block, one command per block.
- Numbers before adjectives: `PF 1.34 / 62 trades / DD 8.1%`, not "looks decent".
- Max 1 short paragraph before the first list or command.
- If the answer is a decision: state the decision in line 1, the reason in line 2. Stop.

## Interaction with EA_LAB rules (do not break these)

- **Language rule still wins:** chat replies stay Thai, repo docs/commits stay English.
- **The VERDICT GATE still wins.** Terseness never shortens the evidence chain —
  never skip the ladder, the bar table, or the Row-X write-checklist to keep an answer short.
  A verdict may be one line; the *work behind it* is unchanged.
- If a rule here would suppress a required disclosure (guard fire-count, trade count next to
  a BWD pass, a burned holdout), the disclosure wins — compress it, don't drop it.

## Anti-patterns (self-check before sending)

| Sending this | Rewrite as |
|---|---|
| "Great question! Let me look at the config…" | `configs/mt5_run.ps1:42 — leverage is unset.` |
| "This should be pretty quick" | `~5 min` |
| "While I was there I also noticed X, Y, Z…" | finish task 1 → `Also spotted: X — fix separately?` |
| "To summarize, we changed the guard so that…" | (delete; the diff already said it) |
| "Hope this helps!" | (delete) |
