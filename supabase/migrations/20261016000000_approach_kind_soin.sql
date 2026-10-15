-- =====================================================================
--  Démarches : nouveau type « soin » (psychomotricien, ergothérapeute…)
-- =====================================================================

alter table public.approaches drop constraint approaches_kind_check;
alter table public.approaches
  add constraint approaches_kind_check
  check (kind in ('rituel', 'medication', 'soin', 'alimentation', 'environnement', 'autre'));
