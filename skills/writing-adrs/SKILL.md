---
name: writing-adrs
description: Use when documenting a technical, architectural, or implementation decision (before or after making it) — recording why an approach was chosen over alternatives, or capturing state so another agent can resume the work later. Triggers include "write an ADR", "document this decision", "architecture decision record", "record this choice", "hand off this work".
---

# Writing ADRs

## Overview

An **Architecture Decision Record (ADR)** captures one significant technical decision: the context that forced it, the choice made, the alternatives rejected, and the consequences. This skill uses the **Nygard format enriched with a "Resumption (for Agent)" section** so that another agent (or your future self) can pick the work up with no extra context.

**Core principle:** one ADR = one decision. Write the *why*, not just the *what*. The code shows what; the ADR explains why this and not that.

## When to Use

- Before making a non-obvious technical/architectural/implementation choice (status `Proposed`).
- After making one, to record the rationale (status `Accepted`).
- When handing off in-progress work an agent must resume — the Resumption section is mandatory here.
- When reversing or replacing a past decision (new ADR, mark the old one `Superseded by NNNN`).

**Do not use for:** trivial choices with no alternatives, project conventions (those go in CLAUDE.md), or transient notes.

## Storage & Naming Convention

- **Default location:** `docs/adr/NNNN-kebab-title.md`
- **Configurable:** if the project already has an ADR directory or a different convention (e.g. `doc/decisions/`, a leading `0001` already in use), follow the existing one. Check before writing: `ls docs/adr/ 2>/dev/null` and look for any existing ADRs in the repo.
- **Numbering:** zero-padded 4-digit sequence, starting at `0001`. The next number = highest existing ADR number + 1. Never reuse or renumber.
- **Content language: English**, regardless of the conversation language. Section headings, body, everything in English.

## Workflow

1. **Locate the ADR directory.** Default `docs/adr/`. If absent, create it. If the project uses another location/convention, follow it.
2. **Compute the next number.** Scan existing `NNNN-*.md`, take the max, add 1, zero-pad to 4 digits.
3. **Slugify the title** to kebab-case for the filename.
4. **Fill the template** (`template.md` in this skill). Keep the canonical Nygard sections — do not invent extra ad-hoc sections.
5. **Set the status** correctly (see lifecycle below).
6. **Always include the Resumption (for Agent) section.** This is the enrichment that makes the ADR actionable for a future agent — never omit it, even for an already-completed decision (in that case, state that the work is done and how to verify it).

## Status Lifecycle

```
Proposed → Accepted → (later) Deprecated
                    → (later) Superseded by NNNN
Proposed → Rejected
```

Always include the date. When superseding, edit the old ADR's status to `Superseded by NNNN` and link both ways.

## Template

Use `template.md` (in this skill directory) as the canonical structure. Its sections:

- **Title** — `# NNNN. Imperative decision summary`
- **Metadata** — Date, Status, Deciders, and optionally Branch/Commit.
- **Context** — the forces, constraints, and problem. Why a decision is needed *now*.
- **Decision** — the choice, stated actively ("We will…"). Concrete and specific.
- **Alternatives Considered** — each option and why it was rejected. This is where the *why* lives.
- **Consequences** — positive, negative, and neutral trade-offs that follow.
- **Resumption (for Agent)** — the enrichment. Everything a fresh agent needs to continue:
  - **Current state** — what is implemented vs pending right now.
  - **Key files / entry points** — exact paths to touch.
  - **Next steps** — concrete remaining tasks, ordered.
  - **How to verify** — commands/tests that confirm correctness.
  - **Gotchas** — non-obvious constraints, footguns, why the easy path fails.
  - **Related** — commits, branches, issues, and other ADRs (`[[NNNN]]`).

## Common Mistakes

| Mistake | Fix |
|---------|-----|
| Saving to `docs/ai/`, `README`, or a non-numbered file | Use `docs/adr/NNNN-title.md` (or the project's existing convention) with a sequence number |
| Omitting the Resumption section | Always include it — it is the whole point of this enriched format |
| Writing only the decision, not the rejected alternatives | The *why* lives in Alternatives Considered; without it the ADR is a changelog |
| Inventing ad-hoc sections | Stick to the canonical Nygard sections + Resumption |
| Writing content in the conversation language | ADR content is always English |
| Bundling several decisions in one ADR | One ADR = one decision; split them |
