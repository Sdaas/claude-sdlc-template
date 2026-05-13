# Review Notes

Observations accumulated during document review session (2026-05-12).
Will be triaged at the end into actionable changes.

---

## Observations

### 1. /exit command shadows built-in

**My observation:** The custom `.claude/commands/exit.md` shadows Claude Code's built-in `/exit`. This is intentional but undocumented.

**Analysis:** Worth noting in OVERVIEW.md or CONTEXT.md so future maintainers don't think it's a conflict. More broadly, any other custom commands that shadow built-ins (e.g. `/review`) should be inventoried and called out explicitly.

---

### 2. Repo vs Template file boundary is unclear

**Your observation:** It is not clear which files belong to the repo and which belong to the template. `CONTEXT.md` clearly belongs to the repo. `README.md` and `.claude/` are part of the template. The audience is different: repo files are for the repo developer; template files are for someone using the template to develop a project.

**Analysis:** This is a significant structural gap. Also worth checking whether `.claude/commands/` files are repo-only or copied by bootstrap — currently CONTEXT.md implies they ARE copied (they're listed under the template file inventory), but the `scaffold/` directory does not contain them. Bootstrap.sh would need to copy `.claude/` explicitly. The current OVERVIEW.md repository map lists all files in one flat view with no indication of which will be present in a bootstrapped project. A clear two-section split (repo-only vs copied-to-project) would help both audiences. The `scaffold/` directory partially addresses this but is not the full picture — `.claude/`, `hooks/`, and `scripts/` also straddle the boundary in non-obvious ways.

---

### 3. Model routing — can Claude check the active model?

**Your question:** (a) Before prompting, can Claude check what model is being used to avoid unnecessary prompting? (b) Before proceeding, can Claude check and confirm the user has actually switched?

**Analysis:**

(a) **Yes.** Claude knows its own model at the time each message is processed. The system prompt injects the current model name (e.g. "You are powered by claude-sonnet-4-6"). Claude can read this and skip the announcement if the correct model is already active.

(b) **Yes, but only passively.** Claude cannot poll for a model change — it has no event mechanism. However, when the user sends the next message ("I've switched"), that message is processed by whatever model is now active. So Claude can verify by checking the current model at the start of that reply and confirming it matches the required model. If it doesn't match, Claude should say so and wait again rather than proceeding.

**Implication for CLAUDE.md Section 4:** The announced routing protocol should be tightened:
- Claude checks current model first; only announces a switch if the wrong model is active
- After user confirms switch, Claude verifies the model before proceeding
- If model still wrong after confirmation, Claude says so explicitly and waits

This eliminates unnecessary interruptions when the correct model is already active, and prevents silently proceeding on the wrong model.

---

### 4. Physical feedback during interactive gates (Luxafor LED via `lux` CLI)

**Your question:** For interactive dialogue gates, can Claude also call a command-line tool alongside the interaction? Specifically: run `lux yellow` at the start of an interactive gate, interact with the user (multiple turns), then run `lux off` when the interaction is complete.

**Analysis:**

Yes, this is fully supported — Claude has bash access and can run `lux yellow` / `lux off` as ordinary shell commands at any point. Three implementation approaches, in order of preference:

1. **CLAUDE.md standing rule (recommended).** Add a rule to CLAUDE.md: "At the start of every interactive gate, run `lux yellow`. When the gate completes (all blocking findings resolved, or plan agreed, etc.), run `lux off`." Claude follows CLAUDE.md unconditionally, so this propagates to all gates automatically with no per-command changes needed.

2. **Per-command instruction.** Add `lux yellow` / `lux off` calls to each `.claude/commands/*.md` file explicitly. More verbose but gives per-gate control (e.g. `lux red` for a blocking finding, `lux green` for a pass).

3. **Claude Code hook.** A `pre_tool_use` or `post_tool_use` hook could fire `lux` based on tool patterns, but hooks don't have a clean "interactive gate start/end" event — they fire on tool calls, not on conversational state transitions. Not the right fit here.

**Richer possibility:** Since `lux` supports colors, the LED could encode gate state more expressively:
- `lux yellow` — gate open, waiting for user input
- `lux red` — blocking finding raised
- `lux green` — gate passed
- `lux off` — no active gate

This would require the per-command approach (option 2) or additional CLAUDE.md rules per gate outcome. Worth deciding how expressive to make it.

---

### 5. SESSION_STATE.md should be read automatically, not require /standup

**Your observation:** CONTEXT.md says SESSION_STATE.md is written by `/exit` and read by `/standup`. Do you really need to run `/standup` to get that state? Claude should read it automatically on startup.

**Analysis:** You're right — this is a friction point with no good justification. Claude Code supports an `init` hook (configured in `.claude/settings.json`) that fires automatically when a session starts in a project directory. SESSION_STATE.md could be read there unconditionally, before the user types anything.

Two distinct things are currently bundled inside `/standup` that should arguably be separated:

1. **Automatic on session start:** Read SESSION_STATE.md, git log, open artifacts — surface current state. This should require zero user action.
2. **Optional user-triggered:** The formatted standup summary presentation. This is a communication act the user may or may not want.

The current design forces the user to type `/standup` to get (1), which means if they forget, they start blind. A better model: Claude reads SESSION_STATE.md automatically on startup and surfaces a one-line status ("Last session ended at CODE REVIEW gate on branch feat/add-dry-run-flag"), then the user can type `/standup` for the full summary if they want it.

The `init` hook in `scaffold/.claude/settings.json` is the right mechanism. CLAUDE.md currently handles this via a standing rule ("Always start with /standup") but a hook would make it structural rather than behavioral.

---

### 6. Workflows should accept a GitHub issue number as input

**Your observation:** The bug/feature workflow should accept a GitHub issue number. User should be able to say "work on GH-42" and Claude should read the issue, classify it correctly (bug/feature/other), and trigger the appropriate workflow.

**Analysis:** This is well within Claude's capabilities — `gh issue view 42` returns the full issue body, labels, and comments. The classification step already exists in the workflow (CLASSIFY gate); it just needs to be fed the issue content rather than a human-supplied description.

Proposed flow:
1. User says `/feature GH-42` or `/bugfix GH-42` or just "work on GH-42"
2. Claude runs `gh issue view 42 --json title,body,labels,comments`
3. Claude reads the issue and classifies: feature / bug / other
4. If "other" (e.g. chore, docs, question) — Claude states it and asks how to proceed
5. Claude confirms classification with user, then enters the correct workflow
6. Artifact folder is named `GH-42/` (already supported per CONTEXT.md Section 3.7)
7. Claude links the issue in PLAN.md and closes it automatically when the PR merges (via `gh issue close` or a `Closes #42` in the PR description)

**Additional consideration:** The natural language trigger "work on GH-42" (without a slash command) should also be supported — CLAUDE.md Section 2 already has a natural language trigger path that requires one confirmation step before proceeding. GH issue input fits cleanly into that path.

**Gap in current design:** The existing commands (`feature.md`, `bugfix.md`) take a free-text description string. They have no logic for fetching an issue. This needs to be added to both the command files and the `workflows/SKILL.md`.

---

### 7. `poet` is deprecated — replace with `brew update-python-resources`

**Your question:** CONTEXT.md flags that `poet` (homebrew-pypi-poet) may not work with `uv export`. Research the current state.

**Research findings:**

1. **`homebrew-pypi-poet` is deprecated.** The maintainer explicitly deprecated it in [issue #74](https://github.com/tdsmith/homebrew-pypi-poet/issues/74), noting that Homebrew now handles resource block generation natively.

2. **The official replacement is `brew update-python-resources`.** This is a built-in Homebrew command that queries installed Python modules and generates resource stanzas directly. It is the current recommended approach per [Homebrew's Python for Formula Authors docs](https://docs.brew.sh/Python-for-Formula-Authors).

3. **`uv export` compatibility with `poet` is therefore moot** — `poet` shouldn't be used at all. The question becomes whether `brew update-python-resources` works with a uv-managed project. The answer is yes: `uv export --no-dev --format requirements-txt` produces a standard pip-compatible requirements file, and `brew update-python-resources` works from the installed packages in a virtualenv — it doesn't care how they were installed.

4. **Alternative:** [`graelo/brew-python-resource-blocks`](https://github.com/graelo/brew-python-resource-blocks) is a newer third-party tool that also generates resource blocks and may work more cleanly with uv.

**Action needed (release.sh):** `release.sh` Step 12 must be updated to replace the `uv export | poet` pipeline with `brew update-python-resources <formula>`. The `homebrew/SKILL.md` and `release/SKILL.md` should also be updated to drop any mention of `poet`.

---

### 8. Extract CONTEXT.md Sections 4 and 5 into a separate file

**Your request:** Move "Known Gaps and TODOs" (Section 4) and "Suggested First Tasks for Claude Code" (Section 5) out of CONTEXT.md into a separate file. Update CONTEXT.md to reference the new file.

**Analysis:** This is a good separation of concerns. CONTEXT.md is a design/architecture reference — it should be stable and readable. The gaps/TODOs list is a living task list that changes frequently as items are resolved. Mixing them makes both harder to maintain.

Proposed new file: `TODO.md` (or `TASKS.md`) at the repo root.

CONTEXT.md Sections 4 and 5 should be replaced with a single line:

> See [TODO.md](TODO.md) for known gaps, open issues, and the prioritized task list for Claude Code.

The new `TODO.md` should preserve the existing Priority 1/2/3 structure from Section 5, and include a "Resolved" section at the bottom (as already called for in CONTEXT.md Section 11) so completed items have a home without cluttering the active list.

---

### 9. SESSION_STATE.md staleness — reconciliation via git state

**Your observation:** CONTEXT.md Section 9 flags that SESSION_STATE.md could be stale if the developer does git operations outside Claude Code between sessions. The question: can Claude reconcile by reading git history and uncommitted modifications at session start?

**Analysis: Yes, and this is fully sufficient.**

Claude has access to everything needed to reconstruct ground truth:

| Source | Command | What it tells Claude |
|--------|---------|----------------------|
| Git log | `git log --oneline -20` | Commits made since SESSION_STATE.md was written |
| Current branch | `git branch --show-current` | Whether developer switched branches outside Claude |
| Uncommitted changes | `git status --short` | Files modified/added/deleted since last commit |
| Staged changes | `git diff --cached --name-only` | What's staged but not committed |
| Stash | `git stash list` | Work parked outside normal flow |
| Open artifacts | `find docs/decisions -name "*.md"` | In-progress DESIGN/PLAN/CODE_REVIEW files |

**Reconciliation logic:**

1. Read SESSION_STATE.md (if it exists) — last known state
2. Run the git commands above — current reality
3. Diff them: if git log shows commits not reflected in SESSION_STATE, those happened outside Claude
4. If current branch ≠ SESSION_STATE branch, flag it explicitly
5. If uncommitted changes exist on files not mentioned in SESSION_STATE, surface them
6. Present a reconciled summary: "SESSION_STATE says X, but git shows Y — proceeding with git as ground truth"

**Key principle:** Git is always authoritative. SESSION_STATE.md is a hint, not a record. When they conflict, Claude trusts git and says so explicitly.

**This closes the open question in CONTEXT.md Section 9.** The reconciliation logic should be specified in `standup/SKILL.md` with the above priority order. No new mechanism needed — just clear rules for which source wins.

---

### 11. Opinionated secrets management decision

**Your observation:** CONTEXT.md Section 9 lists `direnv` + `.envrc` as an unresolved open question. We need a strong opinionated decision, not a "maybe add to DEVELOPER_GUIDE.md."

**Analysis — three distinct secrets contexts to solve separately:**

#### Context 1: Development secrets (local machine, dev/test APIs keys etc.)
**Decision: `direnv` + `.envrc`, with `.envrc` in `.gitignore`.**

- `direnv` automatically loads/unloads env vars when you `cd` into the project — no manual `source` needed, no shell state leakage
- `.envrc` is a plain shell file: `export API_KEY=abc123`
- `.envrc` must be in `.gitignore` and `.gitignore` must be in the scaffold — this is non-negotiable
- `gitleaks` pre-commit hook provides a safety net if someone accidentally stages it
- `direnv` integrates cleanly with `uv` — no conflicts

This is the right choice over alternatives:
- `.env` + `python-dotenv`: requires code changes to load; leaks into the app rather than the shell
- Hardcoding in shell profile: not project-scoped, pollutes all projects
- 1Password CLI / Vault: correct for teams, overkill for the solo developer this template targets

#### Context 2: CI secrets (GitHub Actions)
**Decision: GitHub Actions encrypted secrets, full stop.**

- Secrets are set in repo Settings → Secrets and variables → Actions
- Referenced in workflows as `${{ secrets.API_KEY }}`
- Never in workflow YAML files, never in environment files committed to the repo
- `bootstrap.sh` should print a checklist of secrets the developer needs to configure in GitHub after bootstrapping

#### Context 3: Runtime secrets (secrets used by the CLI when installed by an end user)
**Decision: System keychain via the `keyring` Python library.**

- End users should never be asked to set environment variables to use a CLI tool
- `keyring` uses macOS Keychain, Windows Credential Store, or Linux Secret Service transparently
- CLI stores credentials with `keyring.set_password(service, username, password)`
- CLI retrieves with `keyring.get_password(service, username)`
- This is the pattern used by `gh`, `aws`, `stripe` CLIs — it's the right model

**What goes in the scaffold:**
- `.gitignore` must include `.envrc`
- `DEVELOPER_GUIDE.md` should include a "Secrets Setup" section covering all three contexts
- `bootstrap.sh` should check if `direnv` is installed and warn if not
- `pyproject.toml.template` should include `keyring` as a dependency

**Closes CONTEXT.md Section 9, item 2.** Remove the "optional" framing — this is the mandated approach.

---

### 10. Remove all SQL migration tool references from the template

**Your observation:** SQL migration tooling is not needed by every project. If a project needs it, they can add it themselves. The current references clutter the template and create confusion.

**Analysis:** Agreed. This is scope creep in the template — it adds noise for the majority of projects that either don't use SQL at all or have their own migration approach. The template should be opinionated about what every Python CLI project needs (packaging, CI, testing, linting), not about optional subsystems.

**Files to audit and clean up:**

- `CONTEXT.md` Section 3.14 — remove entirely (the "pending decision" is now resolved: don't include it)
- `CONTEXT.md` Section 9, item 1 — remove the open question
- `.claude/skills/python-cli/SKILL.md` — remove the SQL conventions section
- `scaffold/sql/` — remove the placeholder directory entirely
- Any reference to `sqlfluff` in `.pre-commit-config.yaml.template` and `scaffold/.github/workflows/ci.yml` — remove
- `OVERVIEW.md` scaffold map — remove `sql/` entry
- `TODO.md` (once created) — ensure no SQL migration items carry over

**Note on sqlfluff specifically:** If `sql/` is removed, `sqlfluff` in the pre-commit config and CI workflow becomes dead weight too. Remove it from both. Projects that need SQL linting can add it back.

