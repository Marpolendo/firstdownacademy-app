-- ============================================================
-- First Down Academy — Row Level Security policies
--
-- RUN THIS MANUALLY in the Supabase SQL editor for the project at
-- https://wzylgwvifdfnkmuleoxn.supabase.co BEFORE deploying the
-- app.js / dashboard.html changes in this same commit.
--
-- Why: with RLS off (or unconfigured), anyone holding the publishable
-- anon key — which is public by design, it's embedded in app.js — can
-- call the Supabase REST API directly (e.g. from a browser console)
-- and read or write any row in these tables. That includes every
-- player's full_name, age, and coach linkage. This is a youth
-- platform (ages 8-18), so that gap needs to close before launch.
--
-- This file also adds two SECURITY DEFINER helper functions
-- (my_coach_id, get_coach_id_by_referral_code) so the referral-code
-- lookup used during signup keeps working once profiles is locked
-- down — see the matching app.js / dashboard.html changes.
--
-- Safe to re-run: policies are dropped and recreated each time.
-- ============================================================

-- ---------- helper functions ----------
-- security definer: runs with the function owner's privileges, so it
-- can read `profiles` without itself being blocked by the RLS policies
-- below (and without exposing any other column to the caller).

create or replace function public.my_coach_id()
returns uuid
language sql
stable
security definer
set search_path = public
as $$
  select coach_id from public.profiles where id = auth.uid()
$$;

create or replace function public.get_coach_id_by_referral_code(p_code text)
returns uuid
language sql
stable
security definer
set search_path = public
as $$
  select id from public.profiles where lower(referral_code) = lower(p_code) limit 1
$$;

grant execute on function public.my_coach_id() to authenticated;
grant execute on function public.get_coach_id_by_referral_code(text) to anon, authenticated;

-- ---------- profiles ----------
alter table public.profiles enable row level security;

drop policy if exists "profiles_select_own" on public.profiles;
create policy "profiles_select_own" on public.profiles
  for select to authenticated
  using (auth.uid() = id);

-- a coach can see the full rows of their own players (dashboard roster)
drop policy if exists "profiles_select_own_players" on public.profiles;
create policy "profiles_select_own_players" on public.profiles
  for select to authenticated
  using (coach_id = auth.uid());

-- a player can see their own coach's row (name/team on the dashboard)
drop policy if exists "profiles_select_own_coach" on public.profiles;
create policy "profiles_select_own_coach" on public.profiles
  for select to authenticated
  using (id = public.my_coach_id());

drop policy if exists "profiles_insert_own" on public.profiles;
create policy "profiles_insert_own" on public.profiles
  for insert to authenticated
  with check (auth.uid() = id);

drop policy if exists "profiles_update_own" on public.profiles;
create policy "profiles_update_own" on public.profiles
  for update to authenticated
  using (auth.uid() = id)
  with check (auth.uid() = id);

-- no delete policy: profile rows can't be deleted from the client.

-- ---------- progress ----------
alter table public.progress enable row level security;

drop policy if exists "progress_select_own" on public.progress;
create policy "progress_select_own" on public.progress
  for select to authenticated
  using (auth.uid() = user_id);

drop policy if exists "progress_select_own_players" on public.progress;
create policy "progress_select_own_players" on public.progress
  for select to authenticated
  using (user_id in (select id from public.profiles where coach_id = auth.uid()));

drop policy if exists "progress_insert_own" on public.progress;
create policy "progress_insert_own" on public.progress
  for insert to authenticated
  with check (auth.uid() = user_id);

drop policy if exists "progress_update_own" on public.progress;
create policy "progress_update_own" on public.progress
  for update to authenticated
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

-- ---------- giq_scores ----------
alter table public.giq_scores enable row level security;

drop policy if exists "giq_scores_select_own" on public.giq_scores;
create policy "giq_scores_select_own" on public.giq_scores
  for select to authenticated
  using (auth.uid() = user_id);

drop policy if exists "giq_scores_select_own_players" on public.giq_scores;
create policy "giq_scores_select_own_players" on public.giq_scores
  for select to authenticated
  using (user_id in (select id from public.profiles where coach_id = auth.uid()));

drop policy if exists "giq_scores_insert_own" on public.giq_scores;
create policy "giq_scores_insert_own" on public.giq_scores
  for insert to authenticated
  with check (auth.uid() = user_id);

-- ---------- entitlements ----------
-- populated by your Stripe webhook using the service_role key, which
-- bypasses RLS entirely — no insert/update policy needed here.
alter table public.entitlements enable row level security;

drop policy if exists "entitlements_select_own" on public.entitlements;
create policy "entitlements_select_own" on public.entitlements
  for select to authenticated
  using (auth.uid() = user_id);

-- ---------- giq_shared_scores ----------
-- intentionally public read (score-share.html links are meant to be
-- viewable by anyone with the link, logged in or not).
alter table public.giq_shared_scores enable row level security;

drop policy if exists "giq_shared_scores_select_public" on public.giq_shared_scores;
create policy "giq_shared_scores_select_public" on public.giq_shared_scores
  for select to anon, authenticated
  using (true);

-- No insert policy: nothing in the current codebase writes to this
-- table client-side. Add one scoped to `auth.uid() = user_id` if/when
-- a "share my score" write path is built.
