-- ============================================================
-- Weekly cooldown on GIQ exam retakes
--
-- RUN THIS MANUALLY in the Supabase SQL editor, after
-- 0004_safety_progress.sql.
--
-- Nothing stopped a player from retaking the exam back-to-back to
-- reroll a bad score — the coach roster and dashboard show whatever
-- was most recently saved, so an unlimited-retake player's number
-- doesn't mean the same thing as a one-and-done player's. This adds
-- a rolling 7-day cooldown per owner (user_id or managed_player_id),
-- enforced in the INSERT policy itself so it can't be bypassed by
-- calling the Supabase API directly — the client-side check in
-- giq-exam.html is a courtesy (tells the player when they're next
-- eligible before they spend 8 minutes on it), not the real gate.
-- ============================================================

drop policy if exists "giq_scores_insert_own" on public.giq_scores;
create policy "giq_scores_insert_own" on public.giq_scores
  for insert to authenticated
  with check (
    auth.uid() = user_id
    and not exists (
      select 1 from public.giq_scores existing
      where existing.user_id = auth.uid()
        and existing.taken_at > now() - interval '7 days'
    )
  );

drop policy if exists "giq_scores_insert_managed" on public.giq_scores;
create policy "giq_scores_insert_managed" on public.giq_scores
  for insert to authenticated
  with check (
    managed_player_id in (select id from public.managed_players where parent_id = auth.uid())
    and not exists (
      select 1 from public.giq_scores existing
      where existing.managed_player_id = managed_player_id
        and existing.taken_at > now() - interval '7 days'
    )
  );
