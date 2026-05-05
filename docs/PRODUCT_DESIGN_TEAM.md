# FieldOps3i Product Design Team

The Product Design Team is an advisory layer that keeps FieldOps3i modern, functional, clear, accessible, and enterprise-grade.

It does not directly implement UI changes unless human approval is given.

---

## Design Philosophy

FieldOps3i should feel:

- clear
- calm
- professional
- fast to understand
- trustworthy
- role-aware
- useful for real field operations
- closer to enterprise products like ServiceNow, Salesforce, Apple, Microsoft, Linear, and mature SaaS dashboards

The goal is not decoration. The goal is better operational decision-making.

---

## What Good Design Means Here

A design suggestion is useful only if it improves at least one:

- clarity
- speed
- trust
- accessibility
- decision-making
- error prevention
- field-team usability
- management visibility

Avoid:

- cosmetic-only changes
- trend-chasing
- confusing existing users
- breaking role-specific workflows
- adding animation without purpose
- inconsistent colors, spacing, or components

---

## Design Agents

### fieldops-product-design-lead

Owns product experience direction and decides whether a design suggestion is useful enough to consider.

### fieldops-enterprise-ux-researcher

Researches current enterprise UX and dashboard patterns during intentional review tasks.

### fieldops-dashboard-usability-auditor

Reviews dashboard hierarchy, KPI usefulness, manager decision-making, and operational clarity.

### fieldops-design-system-guardian

Protects spacing, typography, colors, cards, buttons, modals, tables, icons, and design-token consistency.

### fieldops-accessibility-reviewer

Checks keyboard navigation, focus, labels, contrast, modal behavior, screen-reader basics, and accessibility regressions.

### fieldops-microinteraction-designer

Suggests subtle loading, empty, success, error, hover, and focus states that reduce uncertainty without adding visual noise.

---

## Monthly Design Review

Run monthly or before major UI changes.

Workflow:

1. Observe current app behavior.
2. Research current enterprise UX patterns if needed.
3. Suggest relevant improvements.
4. Reject trend-chasing.
5. Score each idea by impact and risk.
6. Add candidate ideas to `docs/PRODUCT_DESIGN_BACKLOG.md`.
7. Ask for human approval before implementation.
8. Test approved changes through `TEST_MATRIX.md`.

---

## Approval Rules

Human approval is required before:

- changing UI workflows
- changing dashboards
- changing role-specific navigation or visibility
- implementing visual redesigns
- adding animations/interactions
- changing layout patterns
- changing accessibility behavior

Low-risk backlog additions do not require implementation approval because they do not change the app.

---

## Output Format for Design Review

Use this format:

- Summary
- Design observations
- Useful current patterns
- Trends to ignore
- Suggested improvements
- Impact score
- Risk score
- Role impact
- Accessibility impact
- Backlog entries proposed
- Human approval needed
