-- ============================================================
-- Enable writing to giq_shared_scores
--
-- RUN THIS MANUALLY in the Supabase SQL editor, after
-- 0005_giq_weekly_cooldown.sql.
--
-- giq_shared_scores already exists with RLS enabled and a public
-- SELECT policy (score-share.html reads it by id, no login required),
-- but 0001's own comment flagged that nothing writes to it yet. This
-- adds that write path plus any columns score-share.html already
-- expects that the table may not have picked up yet.
--
-- No name/email/user identifier is stored here on purpose — a share
-- link is a public, indefinitely-cacheable URL, and this table holds
-- exactly what's shown on it: a grade, a score, and how it was earned.
-- That's also why the INSERT policy below is open to anon as well as
-- authenticated — the whole point of this table is data with nothing
-- to protect.
-- ============================================================

alter table public.giq_shared_scores add column if not exists grade text;
alter table public.giq_shared_scores add column if not exists tier text;
alter table public.giq_shared_scores add column if not exists tier_color text;
alter table public.giq_shared_scores add column if not exists tier_sub text;
alter table public.giq_shared_scores add column if not exists score int;
alter table public.giq_shared_scores add column if not exists correct int;
alter table public.giq_shared_scores add column if not exists accuracy int;
alter table public.giq_shared_scores add column if not exists created_at timestamptz not null default now();

drop policy if exists "giq_shared_scores_insert_public" on public.giq_shared_scores;
create policy "giq_shared_scores_insert_public" on public.giq_shared_scores
  for insert to anon, authenticated
  with check (true);
