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

## Candidate Improvements

| ID | Area | Suggestion | Why it matters | Impact | Risk | Status |
|---|---|---|---|---|---|---|
| PD-001 | Dashboard | Review alert hierarchy | Managers should see urgent operational risks first | High | Low | Proposed |
| PD-002 | Tables | Consider density/readability options | Service data tables need to remain readable as data grows | Medium | Medium | Proposed |
| PD-003 | Empty states | Improve empty/filter states | Reduces confusion when filters return no data | Medium | Low | Proposed |
| PD-004 | Mobile | Review sub-600px dashboard layout | Field users may check data from phones | High | Medium | Proposed |
| PD-005 | Accessibility | Periodic focus/keyboard review | Protects the accessibility foundation introduced in v1.1.0 | High | Low | Proposed |

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
