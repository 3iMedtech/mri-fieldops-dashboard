# PM Architecture — Install Base ↔ Contract ↔ PM Calendar

Design spec for bringing FieldOps3i's preventive-maintenance model in line with
how mature field-service / EAM platforms work. Researched 2026-06-29 against
Salesforce Field Service, SAP Plant Maintenance, IBM Maximo, Microsoft Dynamics
365 Field Service, and CMMS best-practice sources.

## 1. The universal model — a 3-layer chain linked by ID

```
ASSET (machine)  →  CONTRACT (entitlement)  →  MAINTENANCE PLAN (rule)  →  WORK ORDERS (visits)
  anchor of truth     what service is owed        how often + when           generated on cadence
```

| Concept | Salesforce FS | SAP PM | IBM Maximo | Dynamics 365 FS | FieldOps3i |
|---|---|---|---|---|---|
| Machine | Asset | Equipment | Asset/Location | Customer Asset | `config_assets` |
| Contract | Service Contract / Entitlement | Contract | Contract | Agreement | `asset_lifecycle` (+ legacy `cmc_contracts`) |
| PM rule | Maintenance Plan + Maintenance Asset junction + Work Rule | Maintenance Plan + Strategy + Task List | PM record | Agreement Booking Setup | `pm_schedule` |
| Generated visit | Work Order + Service Appointment | Maintenance Call/Order | Work Order | Work Order + Booking | `app_tickets` (PM type) |

**Decisive shared choice:** the Maintenance Plan is created *from* the Asset +
Contract and references both **by ID**. It is never a free-floating list matched
by customer name.

## 2. Field interlinks (the DAG — who feeds whom)

| Source field | → | Effect |
|---|---|---|
| `Contract.start_date` | → | Plan anchor (first PM = start + interval) |
| `Contract.type` (CMC/Warranty/AMC) | → | PM required? (yes; labour-only = no) |
| Contract terms / strategy | → | frequency → interval = 12 ÷ freq |
| `Asset.commission_date` | → | Plan activates only after commissioning |
| `Asset.territory` | → | technician assignment |
| `Asset.status` (active/de_installed) | → | Plan suspends when asset retired |
| Work Order completion date | → | next due date (floating recompute) |

## 3. Generation algorithm (canonical)

- **Floating** (chosen): `next_due = last_completion + interval`. Self-corrects when a visit slips.
- **Fixed/calendar** (alt): `next_due = anchor + N×interval`. For compliance tasks.
- **Generation horizon / lead time** (SAP "call horizon", Salesforce "generation timeframe", Dynamics "generate N days early"): the work order is *materialized* a lead time before the due date so parts/engineer can be arranged. Schedule date ≠ work-order-creation date.
- **Tolerance window**: due date carries a ± window. FieldOps3i seed: `PM_WINDOW_DAYS = 15`.
- **Bounded by `contract_end`**: stop past end → raise a renewal alert.

## 4. FieldOps3i gaps

| Standard | Today | Consequence |
|---|---|---|
| Plan generated from contract+asset | `pm_schedule` standalone, hand-kept | in-warranty machines get no PM |
| Linked by Asset ID | fuzzy town+name (`asset_code` 0/22) | KVC/BGTH/NMR orphaned by a town typo |
| `next_due` auto-rolled on completion | typed manually | drift, missed cycles |
| Generation horizon | none | no lead time |
| Assignment by territory + resource | region string (6 cities) | Unassigned → no engineer |
| Gated by commissioning; suspend on de-install | manual | stale/ghost PMs |

## 5. Target design

1. **`config_assets` = anchor.** Add `commission_date`, `territory`, `primary_engineer_id`.
2. **`asset_lifecycle` = single contract source** (keys by `asset_code`, carries `pm_required`); deprecate fuzzy `cmc_contracts`/name matching.
3. **`pm_schedule` = derived plan, one per asset, keyed by `asset_code`** (backfill linkage). Carries `freq`, `anchor`, `last_pms`, `next_pms`, `status`.
4. **Generation engine:** on contract activation (`renew_asset_lifecycle` RPC) create/refresh the plan; gate on `commission_date`; on PM completion roll `next_pms = completion + 12/freq`; bound by `contract_end`; materialize the PM `app_ticket` at a 15–30 day horizon.
5. **Assignment:** `asset.primary_engineer_id` → else `asset.territory` members → else coverage fallback (e.g. Calicut→Siva); never a silent blank.

## 6. Phased rollout (staging-first, reversible)

- **P1 — Linkage backfill (data):** populate `pm_schedule.asset_code` (and `cmc_contracts.asset_code`) by Asset ID; resolve ambiguous/orphan rows with operator. Kills the KVC/BGTH/NMR class immediately. *Highest leverage, lowest risk.*
- **P2 — Schema (additive):** add `commission_date`, `territory`, `primary_engineer_id` (nullable).
- **P3 — Engine:** generation in `renew_asset_lifecycle` + PM-completion roll + reconcile fn; replace region-string assignment with territory/owner.
- **P4 — Code hardening:** matcher uses `asset_code` first, fuzzy only as fallback; de-installed assets excluded from PM views; "PM-required but unscheduled" warning.

## Sources
Salesforce Field Service Maintenance Plans (Trailhead + dev guide); SAP PM time-based maintenance + call horizon (SAP Community); IBM Maximo Preventive Maintenance (IBM Docs, Maximo Secrets); Dynamics 365 Field Service Agreements (Microsoft Learn); CMMS best practice (Sockeye, Clickmaint, MaintainX).
