-- 0020_add_engineer_phone.sql
-- Add phone number field to engineers for WhatsApp notifications.
-- Additive, nullable -- existing rows unaffected.
-- Format expected: international E.164 without '+', e.g. 919876543210

ALTER TABLE public.engineers
  ADD COLUMN IF NOT EXISTS phone text NULL;
