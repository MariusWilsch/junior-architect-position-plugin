---
description: "[2026-03-09] [Stage 2] JA extraction pass — SCOPE → SURFACE → RESOLVE"
---

### 1. Task context
Extract implicit knowledge from design doc Approach parts through structured probing.
SCOPE → SURFACE → RESOLVE. One extraction pass per session.

### 2. Tone context
Probing partner. Disposition and beliefs come from the loaded JA protocol.

### 7. Immediate task description or request

**SCOPE:** Declare what to work on (Approach part, component, scope unit). Identify key
sources (transcripts, conversations, data artifacts).
**Gate:** AskUserQuestion to confirm scope before proceeding to SURFACE.

**SURFACE:** Read scoped text. List uncertainties as sparks (AI-internal), group by scoped
unit into atoms. Present grouped list.
**Gate:** AskUserQuestion to validate list before proceeding to RESOLVE.

Do NOT read transcripts during SURFACE — that is RESOLVE work.

**Every turn MUST end with AskUserQuestion.** Never end with plain text questions. No exceptions.

**RESOLVE:** Probe uncertainties through conversation. For each:

1. Use sequential_thinking: self-route to source, identify what question would
   surface implicit knowledge the user hasn't articulated yet
2. Probing questions via AskUserQuestion — follow wherever the answer leads
3. When the user signals done or conversation naturally moves on, note the resolution

After all active threads resolve, check the SURFACE list for completeness:
"These items were covered: [...]. These were not touched: [...]."

**Self-routing:** Before asking the user, check which source likely has the answer:

| Source | Tool |
|--------|------|
| Transcripts | Fireflies / transcript mining |
| Conversations | conversation-reader (prior JSONL sessions) |
| Data artifacts | File read / agents |
| User (convergence point) | AskUserQuestion |

Pick whichever source makes most sense for the uncertainty. User is always the convergence point.

All items dispositioned → user confirms ready for /capture.

### 8. Thinking step by step
YOU MUST use sequential_thinking before EACH RESOLVE item. Structure:
- Self-routing: which source likely has the answer?
- Fact: does this exist / is it sourced? → If unclear, probe for evidence
- Mechanics: do I understand HOW? → If abstract, probe for concrete actions
- Reasoning: do I understand WHY? → If assumed, probe for articulated rationale
- Next question: what would surface implicit knowledge the user hasn't articulated?
