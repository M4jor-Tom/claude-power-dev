# NNNN. <Short imperative summary of the decision>

| Field    | Value                                  |
|----------|----------------------------------------|
| Date     | YYYY-MM-DD                             |
| Status   | Proposed \| Accepted \| Rejected \| Deprecated \| Superseded by NNNN |
| Deciders | <names / roles>                        |
| Branch   | <git branch, if relevant>              |
| Commit   | <git sha, if relevant>                 |

## Context

What is the situation, and what forces are at play (technical, business, constraints)?
Why does a decision need to be made now? State the problem neutrally, before the choice.

## Decision

State the decision actively: "We will …".
Be concrete and specific — name the components, files, or patterns affected.

## Alternatives Considered

### <Option A>

What it is, and **why it was rejected** (or chosen).

### <Option B>

What it is, and **why it was rejected**.

(One subsection per alternative. This is where the rationale lives.)

## Consequences

### Positive

- <benefit>

### Negative / Trade-offs

- <cost, risk, or debt incurred>

### Neutral

- <follow-on facts that are neither good nor bad>

## Resumption (for Agent)

> The section that lets a fresh agent continue this work with no extra context.
> Always present — even for completed work (then state it is done and how to verify).

### Current state

What is implemented vs pending at the time of writing.

### Key files / entry points

| File | Role |
|------|------|
| `path/to/file` | <what it does in this decision> |

### Next steps

1. <ordered concrete remaining task>
2. <…>

### How to verify

```bash
# commands / tests that confirm the decision is correctly applied
```

### Gotchas

- <non-obvious constraint, footgun, or why the naive approach fails>

### Related

- Commits: `<sha>`
- Branch: `<branch>`
- Issues: `<link>`
- ADRs: [[NNNN]] <relation: supersedes / superseded by / refines>
