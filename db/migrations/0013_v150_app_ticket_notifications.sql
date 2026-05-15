-- ═════════════════════════════════════════════════════════════════════
-- 0013_v150_app_ticket_notifications.sql
--
-- Creates public.app_ticket_notifications — email send log.
-- Written by the Edge Function after each send attempt (via service key).
-- Admins/managers can query to confirm notification history per ticket.
--
-- Apply order: STAGING → verify → PROD (explicit approval required).
-- Requires: 0012 applied (app_tickets must exist).
-- ═════════════════════════════════════════════════════════════════════

-- ── §1. Notifications table ──────────────────────────────────────────
create table if not exists public.app_ticket_notifications (
  id          uuid          primary key default uuid_generate_v4(),
  ticket_id   text          not null
    references public.app_tickets(id) on delete cascade,
  sent_at     timestamptz   not null default now(),
  sent_by     uuid          references auth.users(id) on delete set null,
  to_email    text          not null,
  cc_emails   text[],
  subject     text,
  status      text          not null default 'sent'
    constraint notification_status_check
      check (status in ('sent', 'failed')),
  error_msg   text
);

-- ── §2. Indexes ──────────────────────────────────────────────────────
create index if not exists app_ticket_notifications_ticket_id_idx
  on public.app_ticket_notifications (ticket_id, sent_at desc);

create index if not exists app_ticket_notifications_sent_at_idx
  on public.app_ticket_notifications (sent_at desc);

-- ── §3. RLS ──────────────────────────────────────────────────────────
alter table public.app_ticket_notifications enable row level security;

-- SELECT: admin and manager only (notification logs are operational data)
drop policy if exists "v150_app_ticket_notifications_select" on public.app_ticket_notifications;
create policy "v150_app_ticket_notifications_select"
  on public.app_ticket_notifications for select
  to authenticated
  using ( public.app_can_write() );

-- INSERT: via service-role key from Edge Function (bypasses RLS).
-- Direct client insert also allowed for admin/manager (manual resend logging).
drop policy if exists "v150_app_ticket_notifications_insert" on public.app_ticket_notifications;
create policy "v150_app_ticket_notifications_insert"
  on public.app_ticket_notifications for insert
  to authenticated
  with check ( public.app_can_write() );

-- No UPDATE or DELETE — notification log is append-only.

-- ── End of 0013 ──────────────────────────────────────────────────────
