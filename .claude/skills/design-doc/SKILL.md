---
name: design-doc
description: >
  Load this skill for any task involving writing a design document, reviewing a
  design document, or evaluating whether a proposed design is ready for
  implementation. Applies to all STANDARD changes in projects built from
  this project. Triggered by /feature and non-trivial /bugfix workflows.
---

# Design Document Conventions

This skill defines what a good design document looks like, how Claude writes one,
and how the design review dialogue is conducted. Design is the first gate in every
STANDARD change. No implementation begins without an approved design.

---

## 1. When a Design Document Is Required

Required for every STANDARD change — features and non-trivial bug fixes.
Not required for TRIVIAL changes.

A change is non-trivial if any of the following are true:

- It adds, removes, or modifies a public interface (CLI flags, function signatures,
  file formats, DB schema)
- It touches more than two source files
- It introduces a new dependency
- It changes behaviour observable by the user
- It has security implications
- The developer or Claude is uncertain about the right approach

When in doubt, write the design doc. A lightweight design doc costs 15 minutes.
A wrong implementation costs days.

---

## 2. Design Document Template

Every design document follows this structure exactly. Sections marked REQUIRED
must be present. Sections marked OPTIONAL may be omitted with a note explaining why.

```markdown
# Design: {Feature or Bug Title}

**Status:** DRAFT | IN REVIEW | APPROVED | SUPERSEDED
**Type:** Feature | Bug Fix
**Trigger:** /feature "{description}" | /bugfix "{description}"
**Artifact folder:** docs/decisions/{slug}/
**Date:** {YYYY-MM-DD}
**Author:** Claude (session) + {developer name}


---

## 1. Context and Motivation  [REQUIRED]

Why does this change exist? What problem does it solve?
What is the current behaviour and why is it insufficient?
Keep this to 3-5 sentences. Do not pad.

## 2. Goals  [REQUIRED]

What must this change achieve? Written as verifiable statements.

- Goal 1
- Goal 2

## 3. Non-Goals  [REQUIRED]

What is explicitly out of scope? This prevents scope creep during implementation.

- Non-goal 1
- Non-goal 2

## 4. Proposed Design  [REQUIRED]

The technical approach. Include:

- What changes and why
- Key interfaces, signatures, or CLI flags being added or modified
- Data flow if relevant
- SQL schema changes if relevant
- Shell script changes if relevant

Use code blocks for interfaces and signatures. Keep prose concise.

### 4.1 Alternatives Considered  [REQUIRED]

At least one alternative must be documented, even if obviously inferior.
Document why the proposed design was chosen over the alternatives.

| Alternative | Why not chosen |
|-------------|---------------|
| {Option A}  | {Reason}      |
| {Option B}  | {Reason}      |

## 5. Interface Changes  [REQUIRED if any interface changes]

Document all changes to public interfaces:

### CLI Changes

```
# Before
{project-name} deploy [OPTIONS]

# After
{project-name} deploy [OPTIONS]
  --dry-run    Simulate deployment without executing
```

### Function Signature Changes

```python
# Before
def deploy(target: str) -> None:

# After
def deploy(target: str, dry_run: bool = False) -> None:
```

### Schema Changes

```sql
-- Migration: 003_add_dry_run_log.sql
ALTER TABLE deployments ADD COLUMN dry_run BOOLEAN NOT NULL DEFAULT FALSE;
```

## 6. Test Strategy  [REQUIRED]

How will this change be tested? Be specific.

- Unit tests: what will be tested in isolation
- Integration tests: what boundaries will be crossed
- Shell tests: which bats tests cover shell script changes
- Edge cases: what failure modes will be tested

## 7. Security Considerations  [REQUIRED]

What are the security implications of this change?
If none, state explicitly: "No security implications identified" with a brief
justification. Do not leave this section empty.

## 8. Rollout and Reversibility  [OPTIONAL]

How is this change deployed? Can it be rolled back?
Required if the change involves schema migrations or breaking interface changes.

## 9. Open Questions  [OPTIONAL]

Questions that are unresolved at design time. Each must be resolved before
APPROVED status is granted.

- [ ] {Question 1} — owner: {developer | Claude}
- [ ] {Question 2}

---

## Approval

| Reviewer | Status    | Date       | Notes |
|----------|-----------|------------|-------|
| Claude   | {status}  | {date}     | Design review complete |
| {name}   | {status}  | {date}     | Human sign-off |
```

---

## 3. How Claude Writes a Design Document

When `/feature` or a non-trivial `/bugfix` is triggered, Claude writes the design
document before anything else happens.

Process:

1. Claude reads any related existing code, open artifacts, and git log
2. Claude drafts the full DESIGN.md — all required sections, no placeholders
3. Claude presents the design section by section, not all at once
4. Developer responds to each section before Claude moves to the next
5. Claude incorporates feedback inline as the discussion progresses
6. When all sections are agreed, Claude updates status to IN REVIEW and
   triggers the design review gate

Rules for writing the design:

- No placeholders — every required section must have real content
- No padding — every sentence must carry information
- Alternatives Considered must have at least one real alternative, not a strawman
- Security Considerations must be substantive — "no security implications" requires
  a brief justification, not just the assertion
- Open Questions must be resolved before moving to APPROVED — if they cannot be
  resolved, the design is not ready

---

## 4. Design Review Dialogue Protocol

Design review follows the standard review protocol from
CLAUDE.md Section 8, with these design-specific additions.

### What Claude Reviews For

Claude reads the complete DESIGN.md and evaluates it against these criteria:

**Completeness**
- All required sections present and substantive
- No unresolved open questions
- Interface changes fully documented

**Correctness**
- Proposed design actually solves the stated problem
- Non-goals are genuinely out of scope, not deferred scope
- Test strategy covers the stated goals

**Simplicity**
- Is this the simplest design that meets the goals?
- Are there abstractions that aren't justified by the requirements?
- Would a senior engineer consider this overcomplicated?

**Risk**
- Are security considerations complete?
- Are schema migrations reversible?
- Are breaking interface changes documented and justified?

**Consistency**
- Does the design follow the conventions in `python-cli` skill?
- Does it follow the SQL conventions if schema changes are involved?
- Does it follow shell script conventions if scripts are involved?

### Review Output Format

```markdown
## Design Review — {Feature Title}

**Date:** {YYYY-MM-DD}
**Reviewer:** Claude
**Status:** IN REVIEW

### Findings

**BLOCKING**

1. {Finding title}
   Section: {section number}
   Issue: {what is wrong}
   Recommendation: {what to change}
   Resolution: {filled in after dialogue}

**NON-BLOCKING**

2. {Finding title}
   Section: {section number}
   Issue: {what could be improved}
   Recommendation: {suggestion}
   Resolution: {filled in after dialogue — or DEFERRED with reason}

### Dialogue Record

**Finding 1 — {title}**
Claude: {finding detail}
Developer: {response}
Claude: {updated recommendation or acknowledgement}
Resolution: {agreed change}

...

### Final Status

All blocking findings resolved: YES | NO
Design approved: YES | NO
Approved by: Claude + {developer name}
Date approved: {YYYY-MM-DD}
```

---

## 5. Approval Criteria

A design is APPROVED when:

- All required sections are present and substantive
- All BLOCKING review findings are resolved
- All Open Questions are resolved or explicitly deferred with owner and timeline
- The developer has given explicit sign-off in the session
- The DESIGN.md status field is updated to APPROVED
- The DESIGN_REVIEW.md is committed alongside DESIGN.md

A design is not approved by silence. Explicit sign-off is required.

---

## 6. Lightweight Design for Simple Standard Changes

Some STANDARD changes are straightforward enough that a full design doc would be
disproportionate — for example, adding a single optional CLI flag with no schema
changes and no security implications.

In these cases, Claude may propose a lightweight design covering only:

- Context and Motivation (2-3 sentences)
- Proposed Design (interface change only)
- Test Strategy (bullet list)
- Security Considerations (one sentence with justification)

Claude must explicitly flag it as a lightweight design and get human agreement
before using this format. When in doubt, use the full template.

---

## 7. What Claude Must Do With This Skill

When writing or reviewing a design document:


- Never use placeholders — all required sections must have real content
- Always present the design section by section, waiting for developer response
- Always include at least one real alternative in Alternatives Considered
- Always make Security Considerations substantive — never leave it empty
- Flag missing required sections as BLOCKING in design review
- Flag unresolved Open Questions as BLOCKING — design cannot be APPROVED with open questions
- Flag designs that appear overcomplicated relative to the stated goals as BLOCKING
- Update DESIGN.md status field accurately throughout the workflow:
  DRAFT → IN REVIEW → APPROVED
- Commit DESIGN.md and DESIGN_REVIEW.md together, before any implementation files
