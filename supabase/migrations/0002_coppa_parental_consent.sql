-- ============================================================
-- COPPA — parent-managed accounts for players under 13
--
-- RUN THIS MANUALLY in the Supabase SQL editor, after
-- 0001_rls_policies.sql. Also requires "Confirm email" to be
-- ENABLED for this project (Authentication → Providers → Email →
-- Confirm email) — the parent-consent flow relies on Supabase's own
-- magic-link email as the verified-contact mechanism. Without it,
-- signInWithOtp still sends a link, but there's no independent proof
-- the parent's email address is real and controlled by them.
--
-- Model: a player under 13 does NOT get their own login. A parent
-- creates the (only) authenticated account, using their own email,
-- verified via a Supabase magic-link click — that's the "verifiable"
-- part of verifiable parental consent. The child's data lives in
-- managed_players, scoped to that parent, with no separate auth.users
-- row and no independent credentials. Players 13+ are unaffected —
-- they keep signing up directly via profiles/auth.users as before.
-- ============================================================

-- ---------- pending_child_signups ----------
-- Holds the signup form's data between submission and the parent
-- clicking the emailed magic link. No PII is "collected" in the
-- COPPA sense (used/disclosed) until the parent consents — this is
-- just staged data tied to a single-use token.
create table if not exists public.pending_child_signups (
  id uuid primary key default gen_random_uuid(),
  token text not null unique,
  child_name text not null,
  child_age int not null check (child_age >= 8 and child_age < 13),
  position text,
  referral_code text,
  parent_name text not null,
  parent_email text not null,
  created_at timestamptz not null default now(),
  expires_at timestamptz not null default (now() + interval '7 days'),
  consumed_at timestamptz
);

alter table public.pending_child_signups enable row level security;

-- anyone can stage a pending signup (this happens before any auth
-- session exists) — no select/update/delete policy is defined, so
-- the row is otherwise invisible/immutable from the client. All
-- reads and the consuming write happen through the SECURITY DEFINER
-- functions below, which validate the token server-side.
drop policy if exists "pending_child_signups_insert_anon" on public.pending_child_signups;
create policy "pending_child_signups_insert_anon" on public.pending_child_signups
  for insert to anon, authenticated
  with check (true);

-- ---------- managed_players ----------
-- A child profile with no auth.users row of its own — access is
-- entirely mediated through the owning parent's session.
create table if not exists public.managed_players (
  id uuid primary key default gen_random_uuid(),
  parent_id uuid not null references auth.users(id) on delete cascade,
  full_name text not null,
  age int not null check (age >= 8 and age < 13),
  position text,
  coach_id uuid references public.profiles(id),
  created_at timestamptz not null default now()
);

alter table public.managed_players enable row level security;

drop policy if exists "managed_players_select_own" on public.managed_players;
create policy "managed_players_select_own" on public.managed_players
  for select to authenticated
  using (auth.uid() = parent_id);

-- a coach can see the managed children linked to their roster
drop policy if exists "managed_players_select_coach" on public.managed_players;
create policy "managed_players_select_coach" on public.managed_players
  for select to authenticated
  using (coach_id = auth.uid());

drop policy if exists "managed_players_update_own" on public.managed_players;
create policy "managed_players_update_own" on public.managed_players
  for update to authenticated
  using (auth.uid() = parent_id)
  with check (auth.uid() = parent_id);

-- fulfils the privacy policy's "parents can delete their child's
-- data" promise — this is a real, working mechanism now.
drop policy if exists "managed_players_delete_own" on public.managed_players;
create policy "managed_players_delete_own" on public.managed_players
  for delete to authenticated
  using (auth.uid() = parent_id);

-- no insert policy: rows are only created via complete_parental_consent()
-- below, so consent is always recorded before a managed_players row
-- can exist.

-- ---------- parental_consents ----------
-- Audit trail: proof consent was actually given, not just claimed.
create table if not exists public.parental_consents (
  id uuid primary key default gen_random_uuid(),
  parent_id uuid not null references auth.users(id) on delete cascade,
  managed_player_id uuid not null references public.managed_players(id) on delete cascade,
  parent_email text not null,
  child_name text not null,
  child_age int not null,
  consented_at timestamptz not null default now(),
  consent_notice_version text not null default 'v1'
);

alter table public.parental_consents enable row level security;

drop policy if exists "parental_consents_select_own" on public.parental_consents;
create policy "parental_consents_select_own" on public.parental_consents
  for select to authenticated
  using (auth.uid() = parent_id);

-- no insert/update/delete policy: written only by
-- complete_parental_consent() below, and never edited afterward —
-- it's a record of what was agreed to at the time.

-- ---------- progress / giq_scores: extend for managed players ----------
alter table public.progress add column if not exists managed_player_id uuid references public.managed_players(id) on delete cascade;
alter table public.giq_scores add column if not exists managed_player_id uuid references public.managed_players(id) on delete cascade;

-- exactly one of (user_id, managed_player_id) must be set
alter table public.progress drop constraint if exists progress_owner_xor;
alter table public.progress add constraint progress_owner_xor
  check ((user_id is not null) <> (managed_player_id is not null));

alter table public.giq_scores drop constraint if exists giq_scores_owner_xor;
alter table public.giq_scores add constraint giq_scores_owner_xor
  check ((user_id is not null) <> (managed_player_id is not null));

-- mirrors whatever unique constraint already backs the user_id-based
-- upsert (module_num,lesson_num) in submitQuiz(), so the same upsert
-- pattern works for managed_player_id too.
create unique index if not exists progress_managed_player_unique
  on public.progress (managed_player_id, module_num, lesson_num)
  where managed_player_id is not null;

-- a parent can read/write progress and scores for their own managed children
drop policy if exists "progress_select_managed" on public.progress;
create policy "progress_select_managed" on public.progress
  for select to authenticated
  using (managed_player_id in (select id from public.managed_players where parent_id = auth.uid()));

drop policy if exists "progress_write_managed" on public.progress;
create policy "progress_write_managed" on public.progress
  for insert to authenticated
  with check (managed_player_id in (select id from public.managed_players where parent_id = auth.uid()));

drop policy if exists "progress_update_managed" on public.progress;
create policy "progress_update_managed" on public.progress
  for update to authenticated
  using (managed_player_id in (select id from public.managed_players where parent_id = auth.uid()))
  with check (managed_player_id in (select id from public.managed_players where parent_id = auth.uid()));

drop policy if exists "giq_scores_select_managed" on public.giq_scores;
create policy "giq_scores_select_managed" on public.giq_scores
  for select to authenticated
  using (managed_player_id in (select id from public.managed_players where parent_id = auth.uid()));

drop policy if exists "giq_scores_insert_managed" on public.giq_scores;
create policy "giq_scores_insert_managed" on public.giq_scores
  for insert to authenticated
  with check (managed_player_id in (select id from public.managed_players where parent_id = auth.uid()));

-- a coach can also read progress/scores for managed children on their roster
drop policy if exists "progress_select_coach_managed" on public.progress;
create policy "progress_select_coach_managed" on public.progress
  for select to authenticated
  using (managed_player_id in (select id from public.managed_players where coach_id = auth.uid()));

drop policy if exists "giq_scores_select_coach_managed" on public.giq_scores;
create policy "giq_scores_select_coach_managed" on public.giq_scores
  for select to authenticated
  using (managed_player_id in (select id from public.managed_players where coach_id = auth.uid()));

-- ---------- functions ----------

-- Looks up a pending signup by token, server-side only — no blanket
-- SELECT policy exists on pending_child_signups, so this is the only
-- way to read one, and it validates expiry/consumption itself.
create or replace function public.get_pending_child_signup(p_token text)
returns table (
  child_name text, child_age int, position text, referral_code text,
  parent_name text, parent_email text, expired boolean, consumed boolean
)
language sql
stable
security definer
set search_path = public
as $$
  select
    child_name, child_age, position, referral_code, parent_name, parent_email,
    (expires_at < now()) as expired,
    (consumed_at is not null) as consumed
  from public.pending_child_signups
  where token = p_token
$$;

grant execute on function public.get_pending_child_signup(text) to anon, authenticated;

-- Completes consent: validates the token, checks the authenticated
-- caller's own verified email matches the pending signup's parent
-- email (so a stolen/guessed token alone isn't enough — the click
-- must have come through that parent's real inbox), then atomically
-- creates the managed_players row, the parental_consents audit row,
-- and marks the pending signup consumed. Runs as the function owner
-- so it can write across all three tables under one check.
create or replace function public.complete_parental_consent(p_token text)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_row public.pending_child_signups%rowtype;
  v_coach_id uuid;
  v_player_id uuid;
begin
  select * into v_row from public.pending_child_signups where token = p_token;

  if v_row.id is null then
    raise exception 'Invalid or unknown consent link.';
  end if;
  if v_row.consumed_at is not null then
    raise exception 'This consent link has already been used.';
  end if;
  if v_row.expires_at < now() then
    raise exception 'This consent link has expired. Please sign up again.';
  end if;
  if lower(auth.email()) is distinct from lower(v_row.parent_email) then
    raise exception 'This consent link must be opened while signed in as the parent email it was sent to.';
  end if;

  if v_row.referral_code is not null then
    v_coach_id := public.get_coach_id_by_referral_code(v_row.referral_code);
  end if;

  insert into public.managed_players (parent_id, full_name, age, position, coach_id)
  values (auth.uid(), v_row.child_name, v_row.child_age, v_row.position, v_coach_id)
  returning id into v_player_id;

  insert into public.parental_consents (parent_id, managed_player_id, parent_email, child_name, child_age)
  values (auth.uid(), v_player_id, v_row.parent_email, v_row.child_name, v_row.child_age);

  update public.pending_child_signups set consumed_at = now() where id = v_row.id;

  return v_player_id;
end;
$$;

grant execute on function public.complete_parental_consent(text) to authenticated;
