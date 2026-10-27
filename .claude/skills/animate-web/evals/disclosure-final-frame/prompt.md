---
tags: [skill-creator]
max_turns: 20
timeout_seconds: 600
allowed_tools: [Read, Glob, Grep, Skill, Write, Edit, Bash]
---

The transcript action outputs ease in and out nicely now, but closing one briefly flashes the entire output before it disappears. If I click again halfway through, it sometimes jumps or ends up closed after I asked it to open. Can you inspect the current shared disclosure and explain the smallest fix and how you'd verify it? Keep the existing easing, lazy rendering, and reduced-motion behavior. Diagnosis and a proposed patch only; don't modify production files, push, or merge.
