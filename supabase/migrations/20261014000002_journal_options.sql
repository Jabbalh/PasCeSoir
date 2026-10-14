-- =====================================================================
--  Raisons et actions paramétrables par journal
--  Les réveils référencent désormais les options par identifiant :
--  renommer une option met à jour tout l'historique.
-- =====================================================================

create table public.journal_options (
  id          uuid primary key default gen_random_uuid(),
  journal_id  uuid not null references public.journals (id) on delete cascade,
  kind        text not null check (kind in ('reason', 'action')),
  label       text not null,
  position    integer not null default 0,
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now(),
  -- option archivée : masquée du choix, mais toujours affichée sur les anciens réveils
  deleted_at  timestamptz
);

create index journal_options_journal_updated_idx on public.journal_options (journal_id, updated_at);

create trigger journal_options_touch before insert or update on public.journal_options
  for each row execute function public.touch_updated_at_profile();

-- ---------------------------------------------------------------------
-- Réveils : identifiants d'options à la place des libellés
-- ---------------------------------------------------------------------
alter table public.wakeups
  add column reason_ids uuid[] not null default '{}',
  add column action_ids uuid[] not null default '{}';

-- Reprise des libellés déjà saisis (placés après les options par défaut)
insert into public.journal_options (journal_id, kind, label, position)
select distinct w.journal_id, 'reason', r.label, 1000
from public.wakeups w, unnest(w.reasons) as r(label);

insert into public.journal_options (journal_id, kind, label, position)
select distinct w.journal_id, 'action', a.label, 1000
from public.wakeups w, unnest(w.actions) as a(label);

update public.wakeups w set
  reason_ids = coalesce((
    select array_agg(o.id order by array_position(w.reasons, o.label))
    from public.journal_options o
    where o.journal_id = w.journal_id and o.kind = 'reason' and o.label = any (w.reasons)
  ), '{}'),
  action_ids = coalesce((
    select array_agg(o.id order by array_position(w.actions, o.label))
    from public.journal_options o
    where o.journal_id = w.journal_id and o.kind = 'action' and o.label = any (w.actions)
  ), '{}')
where cardinality(w.reasons) > 0 or cardinality(w.actions) > 0;

alter table public.wakeups drop column reasons, drop column actions;

-- ---------------------------------------------------------------------
-- Options par défaut pour les journaux existants
-- (les nouveaux journaux sont initialisés par l'application, y compris hors ligne)
-- ---------------------------------------------------------------------
insert into public.journal_options (journal_id, kind, label, position)
select j.id, 'reason', d.label, d.pos
from public.journals j
cross join unnest(array[
  'Cauchemar', 'Faim', 'Soif', 'Couche / pipi', 'Dents', 'Malade / fièvre',
  'Bruit', 'Trop chaud', 'Trop froid', 'Doudou perdu', 'Besoin de câlin', 'Inconnue'
]) with ordinality as d(label, pos)
where not exists (
  select 1 from public.journal_options o
  where o.journal_id = j.id and o.kind = 'reason' and lower(o.label) = lower(d.label)
);

insert into public.journal_options (journal_id, kind, label, position)
select j.id, 'action', d.label, d.pos
from public.journals j
cross join unnest(array[
  'Câlin', 'Bercé', 'Biberon / tétée', 'Verre d''eau', 'Change', 'Médicament',
  'Chanson', 'Remis le doudou', 'Dans notre lit', 'Rien, rendormi seul'
]) with ordinality as d(label, pos)
where not exists (
  select 1 from public.journal_options o
  where o.journal_id = j.id and o.kind = 'action' and lower(o.label) = lower(d.label)
);

-- ---------------------------------------------------------------------
-- Sécurité
-- ---------------------------------------------------------------------
alter table public.journal_options enable row level security;

create policy "options visibles par les membres" on public.journal_options
  for select to authenticated
  using (public.is_journal_member(journal_id));

create policy "création d'option par un membre" on public.journal_options
  for insert to authenticated
  with check (public.is_journal_member(journal_id));

create policy "modification d'option par un membre" on public.journal_options
  for update to authenticated
  using (public.is_journal_member(journal_id))
  with check (public.is_journal_member(journal_id));

grant select, insert, update on public.journal_options to authenticated;
revoke all on public.journal_options from anon;
