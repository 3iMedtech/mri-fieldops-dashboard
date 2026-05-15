-- ═════════════════════════════════════════════════════════════════════
-- 0011_v150_pm_completions_app_link.sql
--
-- Additive: links pm_completions to app_tickets.
-- Adds app_ticket_id FK (nullable) and source column to pm_completions.
-- Existing rows default to source='xlsx'. No existing data is altered.
-- Requires: 0009 applied first (app_tickets must exist).
-- ═════════════════════════════════════════════════════════════════════

alter table public.pm_completions
  add column if not exists app_ticket_id text
    references public.app_tickets(id) on delete set null,
  add column if not exists source text not null default 'xlsx'
    constraint pm_completions_source_check
      check (source in ('xlsx', 'app-ticket'));

create index if not exists pm_completions_app_ticket_id_idx
  on public.pm_completions (app_ticket_id)
  where app_ticket_id is not null;

-- ── End of 0011 ──────────────────────────────────────────────────────
