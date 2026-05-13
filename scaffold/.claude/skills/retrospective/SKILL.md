---
name: retrospective
description: >
  Load this skill at the end of every session, or when /retrospective is
  invoked manually. Defines what Claude analyses, how it structures findings,
  and how the retrospective artifact is persisted. Triggered automatically
  when a feature or bugfix reaches COMMIT gate, or when the developer signals
  the session is ending. Uses Sonnet 4.6.
model: claude-sonnet-4-6
---

# Retrospective Convention

This skill defines the session retrospective process for all projects built
using this SDLC. The retrospective analyses the full session to
surface patterns, inefficiencies, and improvements — making each session
better than the last.

Uses Sonnet 4.6 — needs reasoning capability to identify patterns, not just
summarise.

---

## 1. When Retrospective Runs

### Automatic Triggers

- Feature or bugfix reaches COMMIT gate — retrospective runs before session ends
- Developer signals session is ending ("done for today", "let's stop here",
  "closing up", or similar)
- `/standup` detects a completed feature on main and no active work in progress

### Manual Trigger

- Developer invokes `/retrospective` at any point in a session
- Useful mid-session to course-correct before completing a feature

### What "Session" Means

A session is a single continuous Claude Code conversation. The retrospective
analyses everything that happened in that conversation — all gates, all
exchanges, all decisions, all tool calls.

---

## 2. What Claude Analyses

Claude reads the full session transcript and evaluates it across four
dimensions. Every dimension produces concrete, numbered findings with
actionable recommendations.

### 2.1 Process Dimension

**Question:** Was the SDLC process followed correctly and efficiently?

Claude checks:

- Were all required gates completed in the correct order?
- Were any gates skipped? If so, was explicit approval obtained?
- Were gate transitions clean — did each gate produce its artifact before
  the next gate started?
- Was the change correctly classified (TRIVIAL vs STANDARD) at the start?
- Were review dialogues point-by-point as required, or were multiple findings
  addressed at once?
- Were commit messages Conventional Commits compliant?
- Were commits atomic — one concern per commit?
- Was CI monitored after every push?
- Were CI failures diagnosed and resolved correctly?
- Were model announcements made at each gate transition?

**Example findings:**

```
PROCESS-1 [IMPROVEMENT]
Gate skipped without approval: DESIGN REVIEW was skipped on this feature.
This was agreed verbally but not logged in PLAN.md under "Gate Exceptions"
as required. Next time: log all gate exceptions in PLAN.md before proceeding.

PROCESS-2 [PATTERN]
Review findings addressed in batches: During code review, findings 3 and 4
were addressed together without waiting for individual confirmation.
The review protocol requires one finding at a time.
Next time: present each finding, wait for response, confirm fix, then move on.
```

### 2.2 Cost Dimension

**Question:** Was the right model used at each gate? Were there avoidable
token-expensive loops?

Claude checks:

- Was Haiku 4.5 used for CLASSIFY, PLAN, STANDUP, commit messages?
- Was Sonnet 4.6 used for CODE, CODE REVIEW, SECURITY REVIEW?
- Was Opus 4.6 used for DESIGN and DESIGN REVIEW?
- Were there unnecessary back-and-forth loops that could have been avoided
  with better upfront clarity?
- Were there long regeneration cycles caused by unclear requirements?
- Were there large code blocks generated that were immediately discarded?
- Were there repeated tool calls for the same information?
- How many total exchanges did the session take? Is that proportionate to
  the complexity of the work?

**Cost efficiency rating:** Claude assigns one of:
- EFFICIENT — model routing correct, minimal wasted exchanges
- ACCEPTABLE — minor inefficiencies, no significant waste
- NEEDS IMPROVEMENT — wrong models used, significant avoidable loops
- POOR — major model misrouting or excessive regeneration cycles

**Example findings:**

```
COST-1 [NEEDS IMPROVEMENT]
Opus 4.6 used for PLAN gate: The planning gate was conducted using Opus 4.6
instead of Haiku 4.5. PLAN is a lightweight task — Haiku is sufficient.
Estimated excess cost: ~3x for this gate.
Next time: confirm model selection at gate start before proceeding.

COST-2 [IMPROVEMENT]
3 regeneration cycles on DESIGN.md section 4: The proposed design was
regenerated three times due to unclear requirements about the SQL schema.
This could have been avoided by asking one clarifying question upfront.
Next time: ask about SQL schema requirements before starting the design doc.
```

### 2.3 Effectiveness Dimension

**Question:** Did Claude ask the right questions early? Did assumptions cause
rework? Was the output quality high?

Claude checks:

- Were clarifying questions asked before starting work, or mid-implementation?
- Were any assumptions made that turned out to be wrong?
- How many review findings were BLOCKING? A high number suggests the
  implementation diverged from the design or the design was underspecified.
- Were there any mid-task reclassifications (TRIVIAL → STANDARD)?
- Was the PLAN.md accurate — did the implementation match the plan?
- Were there any test failures caused by implementation mistakes (not
  requirements misunderstanding)?
- How many CI remediation attempts were needed?
- Was the TDD cycle followed cleanly — red → green → refactor?
- Were there any "obvious" issues that a more careful review would have caught?

**Example findings:**

```
EFFECTIVENESS-1 [IMPROVEMENT]
Assumption about file path led to rework: Claude assumed the config file
lived at ~/.config/{project} without confirming. The actual path was
~/.{project}/config. This caused 2 test failures and a full reimplementation
of the path resolution logic.
Next time: ask "where should the config file live?" before implementing
any file path logic.

EFFECTIVENESS-2 [POSITIVE]
TDD cycle was clean throughout: All 8 tests were written red-first, shown
failing, then implemented to green with no skipped steps. This is correct
behaviour — no change needed.
```

### 2.4 Communication Dimension

**Question:** Were prompts clear and specific? Were responses appropriately
concise? Were there communication patterns that slowed things down?

Claude checks:

- Were developer prompts specific and actionable, or did they require
  clarification requests?
- Were Claude's responses appropriately concise, or were they verbose
  without adding value?
- Were there exchanges where Claude misunderstood the developer's intent?
- Were there exchanges where the developer had to repeat or rephrase
  a request?
- Were there long planning discussions that could have been shorter with
  a more structured format?
- Did Claude present options clearly with tradeoffs, or were tradeoffs buried?
- Were gate transition announcements clear (model, gate name, what's next)?

**Example findings:**

```
COMMUNICATION-1 [IMPROVEMENT]
Developer rephrased the same requirement 3 times: The requirement for the
--output-format flag was rephrased as "format", "output format", and finally
"--output-format csv|json|table" before Claude understood the scope.
This suggests Claude should have asked: "What output formats should be
supported and what should the flag be called?" as a single clarifying question.
Next time: when a CLI flag is mentioned without specifying its values, ask
for the full option spec before designing.

COMMUNICATION-2 [IMPROVEMENT]
Design doc presented all at once: The DESIGN.md was presented as a complete
document rather than section by section. This led to feedback on section 4
that conflicted with decisions already embedded in section 2.
Next time: present design section by section, resolve each before moving on.
```

---

## 3. Retrospective Output Format

```markdown
# Retrospective — {feature-slug or session description}

**Date:** {YYYY-MM-DD}
**Session duration:** {approximate — based on artifact timestamps}
**Work completed:** {brief description}
**Model used:** Sonnet 4.6

---

## Summary

{3-5 sentence overview of the session: what was accomplished, overall
quality of the process, and the single most important improvement for
next time.}

---

## Process

**Rating:** ON TRACK | MINOR ISSUES | NEEDS ATTENTION

{Numbered findings}

1. {PROCESS-N} [{POSITIVE | IMPROVEMENT | PATTERN}]
   {Finding title}
   {2-4 sentences: what happened, why it matters, what to do next time}

---

## Cost

**Efficiency rating:** EFFICIENT | ACCEPTABLE | NEEDS IMPROVEMENT | POOR

{Numbered findings}

1. {COST-N} [{POSITIVE | IMPROVEMENT}]
   {Finding title}
   {2-4 sentences: what happened, estimated cost impact, recommendation}

---

## Effectiveness

**Rating:** HIGH | MEDIUM | LOW

{Numbered findings}

1. {EFFECTIVENESS-N} [{POSITIVE | IMPROVEMENT}]
   {Finding title}
   {2-4 sentences: what happened, impact on quality or time, recommendation}

---

## Communication

**Rating:** CLEAR | ACCEPTABLE | NEEDS IMPROVEMENT

{Numbered findings}

1. {COMMUNICATION-N} [{POSITIVE | IMPROVEMENT | PATTERN}]
   {Finding title}
   {2-4 sentences: what happened, why it mattered, concrete recommendation}

---

## Top 3 Recommendations for Next Session

These are the three highest-impact improvements from this retrospective,
ordered by expected benefit.

1. {Most impactful recommendation — one sentence, actionable}
2. {Second recommendation}
3. {Third recommendation}

---

## Recurring Patterns

{List any finding that also appeared in a previous retrospective.
If this is the first retrospective, this section is omitted.}

- {Pattern description} — appeared in {N} of last {N} retrospectives
  Status: {IMPROVING | UNCHANGED | WORSENING}

---

## Developer Notes

{Space for the developer to add their own observations before committing.
Claude leaves this section blank — the developer fills it in.}

---

**Committed by:** Claude (Sonnet 4.6) + {developer name}
**Artifact path:** docs/retrospectives/{YYYY-MM-DD}-{slug}.md
```

---

## 4. Recurring Pattern Detection

Claude reads the last two retrospective artifacts before writing the current
one. It looks for findings that appear across multiple sessions.

A finding is recurring if:

- The same root cause appears in two or more retrospectives, OR
- The same recommendation was made but not acted on

Recurring patterns are flagged prominently — they represent systemic issues
that one-off recommendations have not fixed. They require a different approach:

- IMPROVING — pattern appeared before but severity is reducing
- UNCHANGED — same severity, same frequency — the recommendation is not working
- WORSENING — more frequent or more severe than previous sessions

If a pattern is UNCHANGED after appearing in three consecutive retrospectives,
Claude escalates: "This pattern has appeared 3 times without improvement.
Consider updating CLAUDE.md or the relevant skill to enforce this structurally."

---

## 5. Positive Findings

Not all findings are improvements. Claude explicitly calls out things that
went well. This is important for two reasons:

- It reinforces correct behaviour — positive patterns should be repeated
- It gives an accurate picture of session quality — a retrospective that
  only finds problems is demoralising and inaccurate

Every retrospective must have at least one POSITIVE finding in each dimension,
unless the session was genuinely problematic across the board — in which case
Claude notes this explicitly.

---

## 6. Developer Notes Section

Claude always leaves the "Developer Notes" section blank. This is intentional.

The retrospective artifact is not complete until the developer has had a
chance to add their own observations. Claude presents the retrospective,
waits for the developer to review it, and asks:

"Would you like to add any notes before I commit this retrospective?"

The developer may add notes, edit any of Claude's findings, or approve as-is.
Claude then commits the artifact.

---

## 7. Artifact Storage

```
docs/retrospectives/
├── {YYYY-MM-DD}-{feature-slug}.md        # feature or bugfix retrospective
├── {YYYY-MM-DD}-{YYYY-MM-DD}-session.md  # session-only retrospective (no feature completed)
└── ...
```

Retrospective artifacts are committed to the repository. They are part of
the project's institutional memory. Do not `.gitignore` them.

Commit message:

```
docs(retrospective): add session retrospective {YYYY-MM-DD}
```

---

## 8. What Claude Must Do With This Skill

When conducting a retrospective:

- Always use Sonnet 4.6
- Always read the last two retrospective artifacts before writing — check
  for recurring patterns
- Always analyse all four dimensions — never skip one because "nothing
  happened" in it
- Always include at least one POSITIVE finding per dimension unless the
  session was genuinely poor
- Always produce exactly three top recommendations — no more, no less
- Always leave the Developer Notes section blank — the developer fills it in
- Always present the retrospective to the developer and wait for their review
  before committing
- Never commit the retrospective without developer acknowledgement
- Flag any UNCHANGED recurring pattern that has appeared 3+ times —
  recommend a structural fix in CLAUDE.md or a skill
- Keep findings concise — 2-4 sentences each, never more
- The summary must be readable in under 20 seconds — no walls of text
