# FieldOps3i — Enterprise Architecture & Rebuild Roadmap

How a Field Service Management (FSM) + Enterprise Asset Management (EAM) platform
for a third-party MRI service provider *should* work, and the sequenced plan to
close the gaps in FieldOps3i. Researched against Salesforce Field Service, SAP PM,
IBM Maximo, MS Dynamics 365 Field Service (2026-06).

## 1. Entity model — one spine, linked by ID

```
CUSTOMER/SITE
  └── ASSET (install base, key=code)                  ← the spine
        ├── CONTRACT (asset_lifecycle, FK asset_code) ← entitlement (CMC/Warranty/AMC)
        │     └── PM PLAN (pm_schedule, FK asset_code) ← derived schedule
        │           └── WORK ORDER (PM visit)
        └── WORK ORDER (breakdown/incident)
              ├── VISIT + assigned ENGINEER(s)
              └── PARTS consumed
```
**Rule:** every relationship is by stable `asset_code` (ID), never by name/town strings.

## 2. Lifecycles (state machines)

| Entity | States |
|---|---|
| Asset | Ordered → Commissioned → Active → (Under-repair) → De-installed → (Re-deployed) |
| Contract | Draft → Active → Renewed/Superseded → Expired / Cancelled |
| PM Plan | Pending (pre-commission) → Active → Renewal-due → Suspended |
| Work Order | Open/Unscheduled → Scheduled → In-progress → Resolved → Closed (SLA clock) |

## 3. Cascade rules (the missing glue)

| Action | Cascades to |
|---|---|
| Commission asset | activate PM plan → generate first PM WO |
| Activate/renew contract (pm_required) | create/refresh PM plan (freq+anchor) |
| Contract nearing end | renewal alert; PM stops at contract_end (renewal-due) |
| **De-install asset** | **cancel contract + suspend PM + close open WOs** |
| Complete PM | roll next_pms (cap at contract_end), write history, update metrics |
| Log breakdown | create incident WO + SLA clock + dispatch |
| Assign/return part | decrement stock, link to WO, flag reorder |

## 4. Feature set (target)

- **Install Base**: asset 360, commission/de-install/redeploy, coverage at a glance
- **Contracts**: one source of truth, renewal history, entitlements, expiry pipeline
- **PM**: auto-derived plan, floating/fixed, generation horizon, compliance %
- **Work Orders**: unified PM+corrective, state machine, checklists, sub-WOs
- **Scheduling/Dispatch**: territory + skills + availability; primary owner + backup
- **SLA**: response/resolution clocks, pause logic, breach alerts
- **Spares/Inventory**: stock, consumption, reorder, in-transit, returns
- **Service history/Knowledge**: per-asset timeline, MTBF/MTTR, recurring-fault detection
- **Analytics**: uptime, SLA, PM compliance, renewals, utilization, parts cost; scheduled digests
- **Comms**: engineer/customer notifications; optional customer portal
- **Platform**: RBAC + audit, mobile offline app, integrations (ERP/CRM/IoT remote-monitoring), data-quality guardrails

## 5. Where FieldOps3i is (2026-06)

✅ install base, work orders (PM+incident), service history, RBAC+audit, dashboards,
PM completion-roll+cap (P3a), ID-based PM linkage (P1), asset PM-fields schema (P2/0021).
❌ contract single-source-of-truth (3 overlapping sources), cascade rules (de-install,
contract→PM), auto-generate PM from contract (P3b), territory/skills dispatch, SLA pause,
inventory, mobile-offline, IoT.

## 6. Sequenced rebuild roadmap

| # | Step | Risk | Notes |
|---|---|---|---|
| **R1** | **De-install cascade** — exclude de-installed assets from the "unmatched contract" diagnostic; suspend PM plan on de-install | Low | fixes "de-installed machines still in contract list" |
| **R2** | **Contract consolidation** — migrate `cmc_contracts` → `asset_lifecycle` (with asset_code + status); Contracts page reads only `asset_lifecycle`; stop mixing PM rows into the contract pool | Med | removes the deepest ambiguity (3 sources → 1) |
| **R3** | **PM auto-generation (P3b)** — per-machine freq field on register/renew; `renew_asset_lifecycle` upserts the PM plan; full de-install→contract-cancel cascade | Med-High | dry-run first |
| **R4** | **Dispatch by owner/territory (P3c)** — `primary_engineer_id` → `territory`; unify region/state/territory vocabulary | Med | columns from 0021 |
| **R5** | **Data-quality guardrails** — referential integrity checks; "unmatched/orphan" becomes a true exception report (target 0) | Low | |
| **R6** | **Retire legacy** — drop `INSTALL_BASE_V2` overlay + `cmc_contracts`; DB fully master | Med | after R2 stable |
| **R7+** | SLA pause logic, spares/inventory, mobile-offline, IoT remote-monitoring | High | larger build phases |

Execution rule: every step staging-first, matrix 0 failures, operator approval before prod, small reversible increments.
