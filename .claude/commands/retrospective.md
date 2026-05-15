# /retrospective — Session Retrospective

Triggered by: `/exit` sequence (automatic) or `/retrospective` (manual)
Model: Sonnet 4.6

This command defines the session retrospective for work done on the template
itself (not for projects bootstrapped from it). The primary work product here
is documentation, skills, commands, and configuration — not application code.
The standard scaffold retrospective's Process dimension assumes a TDD/gate
workflow that does not apply here. This version replaces it.

## Immediate Actions

1. Announce:

```
Starting session retrospective (Sonnet 4.6).
Reading session transcript and recent artifacts...
```

2. Run the following to confirm which files changed this session:

```bash
git diff --name-only HEAD
git status --short
```

3. Run the following to verify skill/command pairs for Template Coherence:

```bash
find .claude/commands scaffold/.claude/commands scaffold/.claude/skills -type f -name "*.md" | sort
```

4. Read the last two retrospective artifacts from `docs/retrospectives/`
   before writing anything — check for recurring patterns.

5. Analyse the full session across all five dimensions:
   - Documentation Sync
   - Template Coherence
   - Cost
   - Effectiveness
   - Communication

6. Write the retrospective artifact to:
   `docs/retrospectives/{YYYY-MM-DD}-{slug}.md`
   following the output format below exactly.

7. Present the retrospective to the developer.

8. Say: "Would you like to add any notes before I commit this retrospective?"

9. Wait for developer acknowledgement and any additions to Developer Notes.

10. Commit the retrospective:
    `docs(retrospective): add session retrospective {YYYY-MM-DD}`

11. If triggered by `/exit`: return to the exit command sequence.
    If triggered manually: confirm completion and await next task.

---

## Rules

- Always use Sonnet 4.6
- Always analyse all five dimensions — never skip one
- Always include at least one POSITIVE finding per dimension
- Always produce exactly three top recommendations
- Always leave Developer Notes blank — developer fills it in
- Never commit retrospective without developer acknowledgement
- Flag any UNCHANGED recurring pattern appearing 3+ times —
  recommend a structural fix in CLAUDE.md or this command

---

## 1. What Claude Analyses

Claude reads the full session transcript and evaluates it across five dimensions.
All dimensions produce concrete, numbered findings with actionable recommendations.

### 1.1 Documentation Sync

**Question:** Are all documentation files consistent with the actual state of
the repo after this session's changes?

Claude checks:

- Does the directory listing in `CONTEXT.md` match the actual files on disk?
- Does the directory listing in `scaffold/OVERVIEW.md` match `scaffold/` on disk?
- Does `scaffold/CLAUDE.md` Section 2 (Workflow Triggers) list all commands
  that exist in `scaffold/.claude/commands/`?
- Were any files added, renamed, or deleted this session without a corresponding
  documentation update?
- If a skill was added or removed, was `scaffold/OVERVIEW.md` updated?
- If a command was added or removed, was `scaffold/OVERVIEW.md` updated and was
  `scaffold/CLAUDE.md` updated?

**Proactive vs reactive check (mandatory):**
For every doc update this session, Claude determines *how* it happened:
- **Proactive** — updated in the same exchange as the structural change, without prompting. This is correct behaviour.
- **Reactive** — updated only after the developer pointed out the miss. This is a process failure regardless of whether the end state is correct.

A reactive doc update must be flagged as an IMPROVEMENT finding, not a POSITIVE. End state being correct does not erase the miss.

**Example findings:**

```
DOCSYNC-1 [IMPROVEMENT]
CONTEXT.md directory listing not updated after standup.md deletion.
The commands/ listing in CONTEXT.md still showed standup.md after it was
deleted this session. Documentation should be updated atomically with the
structural change, not as a separate follow-up.
Next time: update CONTEXT.md and OVERVIEW.md in the same commit as the
structural change that makes them stale.

DOCSYNC-2 [POSITIVE]
OVERVIEW.md updated correctly after charter command addition.
Both the commands/ listing and the skills/ listing in OVERVIEW.md were
updated in the same commit that added the files. This is correct behaviour.
```

### 1.2 Template Coherence

**Question:** Are skill/command pairs internally consistent? Does the scaffold
hang together as a coherent whole?

Claude checks:

- For every command in `scaffold/.claude/commands/` that delegates to a skill:
  does the referenced skill exist in `scaffold/.claude/skills/`?
- For skills intended to be user-invocable: does a paired command exist?
  (Skills with no command are valid — flag only if the skill description implies
  a command should exist.)
- Does each command file correctly state the model it uses (matching the skill's
  YAML frontmatter)?
- Are there any commands that reference artifacts, paths, or conventions that
  no longer exist or have been renamed?
- Does `scaffold/CLAUDE.md` Section 4 (Model Routing) correctly reflect the
  models declared in skill frontmatter?

**Example findings:**

```
COHERENCE-1 [IMPROVEMENT]
Command model declaration mismatches skill frontmatter.
retrospective.md states "Model: Sonnet 4.6" but the skill frontmatter declares
claude-sonnet-4-6. These are consistent, but if the model were ever changed in
the frontmatter only, the command description would silently lie to the developer.
Next time: treat the command's model line as derived from the skill frontmatter —
update both atomically.

COHERENCE-2 [POSITIVE]
All skill references in commands resolve correctly.
Every command that invokes "Load the X skill" has a corresponding
skills/X/SKILL.md. No dangling references.
```

### 1.3 Cost

**Question:** Was the right model used? Were there avoidable token-expensive loops?

Claude checks:

- Was Sonnet 4.6 used for structural analysis, documentation updates, and review?
- Was Opus 4.6 used only when architectural judgement was genuinely needed
  (new skill design, SDLC process decisions)?
- Were there unnecessary back-and-forth loops caused by unclear requirements?
- Were there large rewrites of documentation that were immediately discarded?
- Were there repeated reads of the same files?

**Cost efficiency rating:** EFFICIENT | ACCEPTABLE | NEEDS IMPROVEMENT | POOR

**Example findings:**

```
COST-1 [NEEDS IMPROVEMENT]
Opus 4.6 used for a documentation update.
The standup.md deletion and OVERVIEW.md update were performed under Opus 4.6.
These are mechanical, low-judgement tasks — Sonnet 4.6 is sufficient.
Next time: reserve Opus for decisions about SDLC process design or new skill
architecture. Documentation updates and file deletions do not require it.
```

### 1.4 Effectiveness

**Question:** Did Claude ask the right questions early? Did assumptions cause
rework? Was the output quality high?

Claude checks:

- Were clarifying questions asked before making structural changes, or mid-change?
- Were any assumptions made about scope that turned out to be wrong?
- Did the session produce net coherence (the repo is more consistent at the end
  than the start) or net fragmentation (partial changes that leave the repo in
  an ambiguous state)?
- Were observations from `observations.md` or `notes.md` addressed accurately,
  or did the implementation drift from what was described?
- Were changes surgical — did they touch only what was necessary?

**Example findings:**

```
EFFECTIVENESS-1 [IMPROVEMENT]
Scope of OVERVIEW.md update was not confirmed before editing.
Claude updated OVERVIEW.md based on an assumption about which sections needed
changing. Two sections were edited unnecessarily.
Next time: state which lines will change and why before editing documentation
files — confirm if scope is ambiguous.

EFFECTIVENESS-2 [POSITIVE]
Suitability analysis was thorough before customising the retrospective skill.
Claude read the existing retrospective skill, the existing retrospective
artifact, and CONTEXT.md before proposing changes — no rework was needed.
```

### 1.5 Communication

**Question:** Were prompts clear and specific? Were responses appropriately
concise? Were there communication patterns that slowed things down?

Claude checks:

- Were developer prompts specific and actionable, or did they require
  clarification requests?
- Were Claude's responses appropriately concise, or verbose without adding value?
- Were there exchanges where Claude misunderstood the developer's intent?
- Were tradeoffs presented clearly when options existed?
- Were analyses and plans presented before implementation, giving the developer
  a chance to redirect?

**Example findings:**

```
COMMUNICATION-1 [IMPROVEMENT]
Analysis presented as a wall of text.
The suitability analysis for the retrospective skill was presented as a long
prose section. A table comparing fit/gaps would have been scannable in half
the time.
Next time: use tables for comparison analyses — they are faster to read and
easier to redirect.
```

---

## 2. Retrospective Output Format

```markdown
# Retrospective — {brief description of session work}

**Date:** {YYYY-MM-DD}
**Session duration:** {approximate}
**Work completed:** {brief description}
**Model used:** Sonnet 4.6

---

## Summary

{3-5 sentence overview: what was accomplished, overall coherence of the
repo after the session, and the single most important improvement for next time.}

---

## Documentation Sync

**Rating:** IN SYNC | MINOR GAPS | OUT OF SYNC

{Numbered findings}

---

## Template Coherence

**Rating:** COHERENT | MINOR ISSUES | BROKEN

{Numbered findings}

---

## Cost

**Efficiency rating:** EFFICIENT | ACCEPTABLE | NEEDS IMPROVEMENT | POOR

{Numbered findings}

---

## Effectiveness

**Rating:** HIGH | MEDIUM | LOW

{Numbered findings}

---

## Communication

**Rating:** CLEAR | ACCEPTABLE | NEEDS IMPROVEMENT

{Numbered findings}

---

## Top 3 Recommendations for Next Session

1. {Most impactful recommendation — one sentence, actionable}
2. {Second recommendation}
3. {Third recommendation}

---

## Recurring Patterns

{List any finding that also appeared in a previous retrospective.
If this is the first retrospective, omit this section.}

- {Pattern description} — appeared in {N} of last {N} retrospectives
  Status: IMPROVING | UNCHANGED | WORSENING

---

## Developer Notes

{Space for the developer to add observations before committing.
Claude leaves this section blank.}

---

**Committed by:** Claude (Sonnet 4.6) + {developer name}
**Artifact path:** docs/retrospectives/{YYYY-MM-DD}-{slug}.md
```

---

## 3. Recurring Pattern Detection

Claude reads the last two retrospective artifacts in `docs/retrospectives/`
before writing the current one. A finding is recurring if the same root cause
or the same recommendation appears across sessions.

If a pattern is UNCHANGED after three consecutive retrospectives, Claude
escalates: "This pattern has appeared 3 times without improvement. Consider
updating CLAUDE.md or this command to enforce it structurally."
