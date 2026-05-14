-- Migration 0008 — v1.4.3 Engineer Lifecycle
-- Adds status, joined_date, last_working_date columns to public.engineers.
-- Purely additive — no existing columns are dropped or altered.
-- Safe to apply to staging first, then production.

ALTER TABLE public.engineers
  ADD COLUMN IF NOT EXISTS status text NOT NULL DEFAULT 'active'
    CONSTRAINT engineers_status_check
      CHECK (status IN ('active', 'resigned', 'inactive')),
  ADD COLUMN IF NOT EXISTS joined_date       date,
  ADD COLUMN IF NOT EXISTS last_working_date date;

-- Verification query (run after applying):
-- SELECT column_name, data_type, column_default, is_nullable
--   FROM information_schema.columns
--  WHERE table_schema = 'public'
--    AND table_name   = 'engineers'
--    AND column_name  IN ('status', 'joined_date', 'last_working_date');
