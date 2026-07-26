-- ============================================================
-- Safety course progress tracking
--
-- RUN THIS MANUALLY in the Supabase SQL editor, after
-- 0003_giq_result_parent_signup.sql.
--
-- safety.html (6 short lessons: hydration, sportsmanship, injury,
-- recovery, weather, speakup) used to track "completion" only in
-- localStorage, with no login required. It's now gated behind sign
-- up/sign in the same way the main curriculum is, so completions need
-- a real, account-tied home — a separate table rather than reusing
-- `progress`, since that table's module_num is 1-8 and several places
-- (dashboard's "X / 8" fraction, the module unlock/gating loop) assume
-- every row in it belongs to the 8-module curriculum.
-- ============================================================

create table if not exists public.safety_progress (
  id uuid primary key default gen_random_uuid(),
  user_id uuid references auth.users(id) on delete cascade,
  managed_player_id uuid references public.managed_players(id) on delete cascade,
  lesson_id text not null,
  completed_at timestamptz not null default now(),
  constraint safety_progress_owner_xor check ((user_id is not null) <> (managed_player_id is not null))
);

create unique index if not exists safety_progress_user_unique
  on public.safety_progress (user_id, lesson_id)
  where user_id is not null;

create unique index if not exists safety_progress_managed_unique
  on public.safety_progress (managed_player_id, lesson_id)
  where managed_player_id is not null;

alter table public.safety_progress enable row level security;

-- a player (13+) can read/write their own rows
drop policy if exists "safety_progress_select_own" on public.safety_progress;
create policy "safety_progress_select_own" on public.safety_progress
  for select to authenticated
  using (auth.uid() = user_id);

drop policy if exists "safety_progress_insert_own" on public.safety_progress;
create policy "safety_progress_insert_own" on public.safety_progress
  for insert to authenticated
  with check (auth.uid() = user_id);

drop policy if exists "safety_progress_update_own" on public.safety_progress;
create policy "safety_progress_update_own" on public.safety_progress
  for update to authenticated
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

-- a parent can read/write progress for their own managed children
drop policy if exists "safety_progress_select_managed" on public.safety_progress;
create policy "safety_progress_select_managed" on public.safety_progress
  for select to authenticated
  using (managed_player_id in (select id from public.managed_players where parent_id = auth.uid()));

drop policy if exists "safety_progress_insert_managed" on public.safety_progress;
create policy "safety_progress_insert_managed" on public.safety_progress
  for insert to authenticated
  with check (managed_player_id in (select id from public.managed_players where parent_id = auth.uid()));

drop policy if exists "safety_progress_update_managed" on public.safety_progress;
create policy "safety_progress_update_managed" on public.safety_progress
  for update to authenticated
  using (managed_player_id in (select id from public.managed_players where parent_id = auth.uid()))
  with check (managed_player_id in (select id from public.managed_players where parent_id = auth.uid()));

-- a coach can read safety progress for players/managed players on their roster
drop policy if exists "safety_progress_select_coach" on public.safety_progress;
create policy "safety_progress_select_coach" on public.safety_progress
  for select to authenticated
  using (user_id in (select id from public.profiles where coach_id = auth.uid()));

drop policy if exists "safety_progress_select_coach_managed" on public.safety_progress;
create policy "safety_progress_select_coach_managed" on public.safety_progress
  for select to authenticated
  using (managed_player_id in (select id from public.managed_players where coach_id = auth.uid()));
