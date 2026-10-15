# Lean In: setup (about 5 minutes)

1. Install Node 20+ and Claude Code (https://code.claude.com/docs), and sign in.
2. Unzip, then in the folder run:
   ```
   git init
   npm install nuxt sass
   claude
   ```
3. First message to paste into Claude Code:
   > Read PRD.md and CLAUDE.md. Do milestone 1 only: build the minimal useRAF, useSpring, GlCanvas and GLSL chunks, then the glowLayer shader on screen, driven by the mouse through useSpring. Keep it small. Stop when it runs and tell me what to look at.
4. See it at http://localhost:3000 (Claude will run `npm run dev`, or run it yourself).
5. Then one milestone per message: "Do milestone 2", "Do milestone 3", and so on.

## Handy
- Skills load on their own; call one directly, e.g. `/moonshot-designer polish the idle state`.
- `claude --continue` reopens the last chat in this folder; `claude --resume` lets you pick one.
- `/context` shows which CLAUDE.md files loaded.
- `docs/future-ideas/` holds two other project PRDs (The Reef, Shader Seedbed) for later.
