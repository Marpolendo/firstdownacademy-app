-- ============================================================
-- COPPA follow-up — let the GIQ quiz-result signup modal
-- (giq-result.html) go through the parent-consent flow too.
--
-- RUN THIS MANUALLY in the Supabase SQL editor, after
-- 0002_coppa_parental_consent.sql.
--
-- giq-result.html lets an anonymous visitor take the quiz, then offers
-- a "Save Your Results" signup modal. That modal previously had no
-- age branching, so a child under 13 could create their own account
-- directly through it, bypassing the parent-consent flow entirely.
-- This migration lets the same staged-signup token also carry the
-- quiz result, so it can be attached to the managed_players row the
-- moment the parent consents — the score isn't lost by routing
-- through the slower, verified path.
-- ============================================================

alter table public.pending_child_signups add column if not exists giq_score int;
alter table public.pending_child_signups add column if not exists giq_grade text;
alter table public.pending_child_signups add column if not exists giq_correct int;
alter table public.pending_child_signups add column if not exists giq_pillars jsonb;

-- Redefine complete_parental_consent to also write the staged quiz
-- score into giq_scores (under the new managed_player_id) when one was
-- attached at signup time.
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

  if v_row.giq_score is not null then
    insert into public.giq_scores (
      managed_player_id, score, grade, correct, taken_at,
      pillar_rulesobjectives, pillar_positionsresponsibilities,
      pillar_formationsalignments, pillar_playsconcepts, pillar_situationalawareness
    ) values (
      v_player_id, v_row.giq_score, v_row.giq_grade, v_row.giq_correct, now(),
      v_row.giq_pillars ->> 'pillar_rulesobjectives',
      v_row.giq_pillars ->> 'pillar_positionsresponsibilities',
      v_row.giq_pillars ->> 'pillar_formationsalignments',
      v_row.giq_pillars ->> 'pillar_playsconcepts',
      v_row.giq_pillars ->> 'pillar_situationalawareness'
    );
  end if;

  update public.pending_child_signups set consumed_at = now() where id = v_row.id;

  return v_player_id;
end;
$$;

grant execute on function public.complete_parental_consent(text) to authenticated;
