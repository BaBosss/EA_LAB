---
name: github-https-repo-auth
description: Diagnose and guide GitHub HTTPS git push/pull authentication for one repository without logging out existing GitHub accounts or switching to SSH. Use when the user wants repo-scoped GitHub HTTPS credentials, personal access token setup, macOS Keychain/git credential helper repair, separate GitHub account publishing, 403 push errors, "could not read Password", "Device not configured", or credential.useHttpPath workflows.
---

# GitHub HTTPS Repo Auth

Use this skill when the user needs GitHub HTTPS authentication for a specific repo, especially when they do not want to log out of an existing GitHub account or use SSH.

Be careful, current, and token-safe. Do not ask the user to paste secrets into chat. Do not print, retrieve, expose, or log tokens. If GitHub UI labels differ from memory, verify with official GitHub docs or ask the user what page they are on instead of guessing.

## Core Rule

Respect the transport the user chose.

If the user asks for HTTPS, solve HTTPS. Do not pivot to SSH unless the user explicitly asks for an SSH alternative.

## Safety Rules

- Never ask the user to paste a PAT, password, OTP, or API key into chat.
- Have the user paste tokens only into their local terminal prompt.
- Use `read -rsp "GitHub token: " GH_TOKEN; echo` instead of putting tokens directly in shell commands.
- Unset token variables after use.
- Do not run commands that would print a stored credential unless the token is masked before output.
- Prefer repo-local git config over global config.

## First Diagnosis

Check the actual state before advising:

```bash
git status --short --branch
git remote -v
git config --local --get-regexp '^credential|^user\.|^remote\.origin'
```

Interpret common failures:

- `Could not resolve host: github.com`: network or sandbox/DNS problem, not credentials.
- `could not read Password ... Device not configured`: Git did not find a usable HTTPS credential.
- `The requested URL returned error: 403`: authentication worked, but the token/account lacks permission for the repo/action.
- `Repository not found`: wrong repo URL, repo does not exist, or authenticated account has no access.
- `denied to USER`: GitHub recognized `USER`, but that user/token cannot write to the repo.

## Repo-Scoped HTTPS Credential Setup

For macOS Keychain or any configured Git credential helper, scope the credential to this repo path:

```bash
git config --local credential.useHttpPath true
git config --local credential.https://github.com.username USERNAME

Reject a bad saved credential before approving a replacement:

```bash
printf "protocol=https\nhost=github.com\npath=OWNER/REPO.git\nusername=USERNAME\n\n" | git credential reject
```

Approve a new token without exposing it:

```bash
read -rsp "GitHub token: " GH_TOKEN; echo
printf "protocol=https\nhost=github.com\npath=OWNER/REPO.git\nusername=USERNAME\npassword=$GH_TOKEN\n\n" | git credential approve
unset GH_TOKEN
```

Then push:

```bash
git push origin BRANCH
```

## Token Guidance

For HTTPS Git operations, GitHub uses a personal access token in place of an account password.

For classic PATs:

- Use `public_repo` for public repositories when that is enough.
- Use `repo` for private repositories or when public-only scope is not enough.

For fine-grained PATs:

- Select the correct resource owner.
- Grant access to the exact repository.
- Give repository contents write permission if the UI exposes that option.
- If labels differ or the option is missing, verify the current GitHub docs instead of insisting on a remembered label.

If a token was created before the repo existed, recreate or edit the token so the repo is included.

## Verification Without Leaking Secrets

To check whether Git can find a credential, mask the password:

```bash
printf "protocol=https\nhost=github.com\npath=OWNER/REPO.git\nusername=USERNAME\n\n" \
  | git credential fill \
  | sed -n '/^username=/p; /^password=/s/.*/password=<present>/p'
```

Expected success includes:

```text
username=USERNAME
password=<present>
```

If it still prompts or reports `could not read Password`, no matching credential is stored for that repo path.

## Handling The Interactive Read Step

If the terminal appears to hang after:

```bash
read -rsp "GitHub token: " GH_TOKEN; echo
```

that is usually normal. It is waiting for the user to paste the token and press Enter, and it will not echo the token.

Warn the user not to paste a whole multi-line block that includes `read` plus later commands unless they understand how the terminal will buffer input. For reliability, run the token read step separately.

## Common Fix Patterns

No credential found:

1. Confirm `credential.useHttpPath=true`.
2. Reject the old credential key.
3. Approve a fresh token.
4. Push again.

403 denied:

1. Confirm the authenticated username in the error.
2. Confirm the token belongs to the intended account.
3. Confirm the token has write access to the repo.
4. Replace the token if it was created with insufficient scope.

Wrong account:

1. Keep global `gh auth` untouched unless the user asks.
2. Use repo-local `credential.https://github.com.username`.
3. Use repo-path-scoped credential approval.

UI mismatch:

1. Stop claiming exact labels from memory.
2. Ask which token page the user is on, or verify official docs.
3. Provide a fallback that matches the visible UI, such as classic PAT scopes for HTTPS push.

## Notes

Use these as practical cautions, not hard rules:

- Prefer repo-local changes when the problem is repo-specific.
- Keep the user's chosen transport unless they ask for alternatives.
- Keep secrets out of chat and mask credential output.
- Interpret errors from the observed command output, not from a fixed script.
- Verify current GitHub UI or docs when exact token labels matter.
