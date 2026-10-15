-- =====================================================================
--  Démarches : rituel, médication… mis en place sur une période
--  (date de fin vide = toujours en cours)
-- =====================================================================

create table public.approaches (
  id          uuid primary key default gen_random_uuid(),
  journal_id  uuid not null references public.journals (id) on delete cascade,
  kind        text not null check (kind in ('rituel', 'medication', 'alimentation', 'environnement', 'autre')),
  label       text not null,
  start_date  date not null,
  end_date    date,
  -- moments de la journée où la démarche a lieu (aucun, un ou plusieurs)
  periods     text[] not null default '{}'
              check (periods <@ array['matin', 'midi', 'apres_midi', 'soir', 'nuit']::text[]),
  comment     text not null default '',
  created_by  uuid default auth.uid() references public.profiles (id) on delete set null,
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now(),
  deleted_at  timestamptz,
  constraint approaches_dates_check check (end_date is null or end_date >= start_date)
);

create index approaches_journal_updated_idx on public.approaches (journal_id, updated_at);

create trigger approaches_touch before insert or update on public.approaches
  for each row execute function public.touch_updated_at();

-- ---------------------------------------------------------------------
-- Sécurité
-- ---------------------------------------------------------------------
alter table public.approaches enable row level security;

create policy "démarches visibles par les membres" on public.approaches
  for select to authenticated
  using (public.is_journal_member(journal_id));

create policy "création de démarche par un membre" on public.approaches
  for insert to authenticated
  with check (public.is_journal_member(journal_id) and created_by = auth.uid());

create policy "modification de démarche par un membre" on public.approaches
  for update to authenticated
  using (public.is_journal_member(journal_id))
  with check (public.is_journal_member(journal_id));

grant select, insert, update on public.approaches to authenticated;
revoke all on public.approaches from anon;
