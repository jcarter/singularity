---
name: distill
description: Consolidate recent Singularity session notes into learnings and a weekly digest
argument-hint: "[days back, default 14]"
---

# Distill Singularity Sessions

Consolidate recent session notes into reusable learnings and a weekly digest.

## Process

1. **Read recent sessions** — List files in `Singularity/Sessions/` and read all notes from the last $ARGUMENTS days (default: 14 days if no argument given)

2. **Identify patterns** — Look across all sessions for:
   - Recurring themes or technologies
   - Decisions that came up multiple times
   - Techniques or patterns worth remembering
   - Mistakes or gotchas encountered

3. **Write learning notes** — For each distinct insight, create or update a file in `Singularity/Learnings/`:
   - Use the Singularity Learning template format
   - If a learning file for that topic already exists, append to it rather than creating a duplicate
   - Link back to the source session notes

4. **Write weekly digest** — Create `Singularity/Distilled/YYYY-Www-weekly-digest.md` with:

```markdown
---
date: YYYY-MM-DD
period: YYYY-MM-DD to YYYY-MM-DD
sessions: [list of session filenames]
tags: [distilled, weekly]
---

# Weekly Digest: Week of YYYY-MM-DD

## Summary
1-3 sentence overview of the week's work.

## Key Themes
- Theme 1: brief description
- Theme 2: brief description

## Decisions Made
- Decision and rationale (link to session)

## Learnings
- Links to new/updated learning notes

## Open Questions
- Unresolved items carried forward
```

5. **Write architectural decisions** — If any sessions contain significant architectural decisions, create files in `Singularity/Decisions/`:

```markdown
---
date: YYYY-MM-DD
project: project-name
tags: [decision, topic]
---

# Decision: Title

## Context
What prompted this decision.

## Decision
What was decided.

## Rationale
Why this approach was chosen over alternatives.

## Consequences
What this means going forward.
```

## Rules

- Never duplicate content that already exists in Learnings/
- Always link back to source sessions
- Keep the digest concise — it's a summary, not a copy
- If there are fewer than 3 sessions, mention that in the digest and keep it brief
- Use the MCP tools: `search`, `get_file_contents`, `list_files_in_dir`, `create_file`, `append_to_file`
