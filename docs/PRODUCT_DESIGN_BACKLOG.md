# FieldOps3i Product Design Backlog

Use this backlog to store product design suggestions before implementation.

Design ideas should be added here before code changes unless the user explicitly approves immediate implementation.

---

## Status Values

- Proposed
- Approved
- In Progress
- Shipped
- Rejected
- Deferred

---

## Shipped

| ID | Area | What shipped | Version |
|---|---|---|---|
| PD-S01 | Visual polish | Toast notification system (replaces alert for feedback) | v1.4.2 |
| PD-S02 | Visual polish | Sidebar active state — gradient + glow ring | v1.4.2 |
| PD-S03 | Visual polish | Panel left-accent bar with hover colour shift | v1.4.2 |
| PD-S04 | Visual polish | Table row hover — brand-tinted gradient + left flash | v1.4.2 |
| PD-S05 | Visual polish | Input focus glow (search boxes) | v1.4.2 |
| PD-S06 | Visual polish | Badge border outlines — all 11 variants | v1.4.2 |
| PD-S07 | Visual polish | KPI card colour glow — all 6 variants | v1.4.2 |
| PD-S08 | Mobile | Contracts table card layout (<768px) — 9-column table replaced with labeled cards | v1.4.3 |

---

## Candidate Improvements

| ID | Area | Suggestion | Why it matters | Impact | Risk | Status |
|---|---|---|---|---|---|---|
| PD-001 | Dashboard | Review alert hierarchy | Managers should see urgent operational risks first | High | Low | Proposed |
| PD-002 | Tables | Consider density/readability options | Service data tables need to remain readable as data grows | Medium | Medium | Proposed |
| PD-003 | Empty states | Improve empty/filter states | Reduces confusion when filters return no data | Medium | Low | Proposed |
| PD-004 | Mobile | Review sub-600px dashboard layout | Field users may check data from phones | High | Medium | Proposed |
| PD-005 | Accessibility | Periodic focus/keyboard review | Protects the accessibility foundation introduced in v1.1.0 | High | Low | Proposed |
| PD-006 | Testing | Extend matrix to PM Schedules + Engineer Perf tabs per role | Those tabs were not exercised in current matrix; role-gating bugs can hide there | High | Low | Proposed |
| PD-007 | Testing | Add console-error assertion to matrix (currently captured but not failing) | JS errors on load would be silently missed | High | Low | Proposed |
| PD-008 | Contracts | `.page-header` gradient underline class — apply to section titles | CSS rule was added in v1.4.2 but not yet wired to HTML | Low | Low | Proposed |
| PD-009 | UX | Renew modal — show current contract end date as helper text | User must know what they're renewing from; currently no context shown | Medium | Low | Proposed |
| PD-010 | UX | Contracts table — show AMC badge count in expiry filter chips | AMC is a new type; filter counts don't currently show it separately | Low | Low | Proposed |
| PD-011 | UX | Toast persistence for warnings (currently 4 s) — extend to 8 s for errors | 4 s is too short to read a long error message from an XLSX parse failure | Medium | Low | Proposed |
| PD-012 | Dashboard | Contract Expiry Overview KPI cards — add Renew button directly on expired card | One-click path from dashboard alert to renewal action | High | Medium | Proposed |
| PD-013 | Mobile | Contracts table collapses poorly below 768 px — too many columns | Field managers checking status on phones see truncated data | High | Medium | Shipped |
| PD-014 | Security | Production Engineer password is complex; staging is `Shiva@23S` — unify or document | Credential drift causes login failures in tests and onboarding | Medium | Low | Proposed |
| PD-015 | Testing | Persist matrix script to `scripts/test-matrix.js` in repo | Currently lives in /tmp and is lost on restart | High | Low | Proposed |

---

## Notes

Do not implement backlog items without approval.

Every approved item must include:

- affected screen/module
- reason
- expected benefit
- risk
- test coverage from `TEST_MATRIX.md`
- release impact
