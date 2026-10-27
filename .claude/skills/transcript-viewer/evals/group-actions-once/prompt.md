---
tags: [skill-creator]
max_turns: 20
timeout_seconds: 600
allowed_tools: [Read, Glob, Grep, Skill, Write, Edit, Bash]
---

For one user prompt I have model prose, a Bash call, more prose, a Think-only turn, and a Read call. The demo shows some work twice, and hiding user prompts seems to merge action groups. I want one action list after the first model prose, visible by default with each output closed; compact should collapse the list. Please inspect how this is wired and propose the fix and validation cases. Keep the reference styling, Think output box, and Bash input label/$ without the extra terminal icon. Don't edit production files, publish a package, push, or merge.
