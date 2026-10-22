---
name: criteria-audit
description: Audit a product, direction or idea with the three hard criteria and three axes (including the AI test), then output a filled checklist, verdict and stop-loss. Use when the user asks "is this worth doing", "should I build this", "帮我判断这个方向", or wants a go/no-go decision.
---

# Criteria Audit

A repeatable audit for "should I build this?" questions. The goal is not to encourage or discourage — it is to make the judgement *structural*.

## When to use

- User asks whether a product / direction / idea is worth doing.
- User asks for a go/no-go decision, or a stop-loss.
- User wants to compare two candidate directions.

## Steps

1. **Compress into one line**
   `[who] pays [how much] for [what they can take and use]`
   If "who pays" is unclear, say so and stop.

2. **Three hard criteria**
   - ① Deliverable usable: can the user take something away and use it? (Content/analysis/opinion → no.)
   - ② Non-employment income: is the money paid outside an employment relationship? (Salary → no; ads/IAP ≈ 0; direct payment → yes.)
   - ③ Portable: after leaving the employer/platform, is it still theirs?
   All three must pass; otherwise it does not produce autonomy.

3. **Three axes** (keep separate, never merge)
   - Compliance: only the three criteria above.
   - Feasibility: minimum scale to monetize, distance from current skills, free tools solving 80%, **AI test**.
   - Risk: single point of cut (platform/payment/compliance), **AI commoditization**, competition.

4. **AI test**
   - Can a free LLM / code agent reach 80 points in 10 minutes? End-to-end?
   - What is the remaining 20% (accountability, context, integration, trust, compliance, maintenance) — and is any of it yours?

5. **Pricing threshold** (if it charges money)
   Check: DIY cost ≥ 2× price; something AI can't get; verifiable; measurable; repeatable.

6. **Quadrant & decision**
   - complies × feasible → do it, validate in small steps
   - complies × not feasible → change form / wait / side line
   - doesn't comply × feasible → cash flow only, not autonomy
   - doesn't comply × not feasible → drop

7. **Stop-loss**
   Write time box + a single binary metric.

## Output format

```text
Object: ...
One line: who / pays how much / gets what
① usable: yes/no  ② non-employment: yes/no  ③ portable: yes/no
→ all three? ...

Feasibility: min scale __ / distance __ / free or AI 80%? __ / AI test: __/10
Risk: single point __ / compliance __ / AI commoditization __ / competition __

Verdict: do / cash flow only / change form / drop
Stop-loss: __ weeks, metric: __
```

## Rules

- Never invent facts about the user's situation; ask or mark as unknown.
- Keep the three axes separate; do not let feasibility or risk impersonate compliance.
- If the object is content with no price, say plainly it is a channel, not a product.
