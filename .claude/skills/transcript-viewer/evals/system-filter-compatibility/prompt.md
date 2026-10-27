---
tags: [skill-creator]
max_turns: 20
timeout_seconds: 600
allowed_tools: [Read, Glob, Grep, Skill, Write, Edit, Bash]
---

We need a filter to hide system turns in the transcript sidebar. Older saved filter objects won't have a system key, and one host controls filters itself. Please inspect the canonical filtering path and plan the change, including what happens to counts, clear/reset, selected turns, and host panels. A checkbox-only test isn't enough. Keep existing anchors, tool filters, and share/review exits working. Planning only: don't modify files, extend the wire schema, or push.
