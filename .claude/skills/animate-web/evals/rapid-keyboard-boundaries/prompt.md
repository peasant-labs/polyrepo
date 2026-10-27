---
tags: [skill-creator]
max_turns: 20
timeout_seconds: 600
allowed_tools: [Read, Glob, Grep, Skill, Write, Edit, Bash]
---

Near the bottom of a long transcript, pressing j or ArrowDown quickly gets selection stuck even though another turn is visible. At the top, a burst of k has the same problem. Waiting between keys mostly works. Inspect the navigation code and outline the likely failure modes, a minimal correction, and regression cases. I still want normal manual scrolling and smooth deliberate jumps. Don't edit production files or push anything yet.
