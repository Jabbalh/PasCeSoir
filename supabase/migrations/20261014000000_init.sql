-- =====================================================================
--  Pas ce soir — schéma initial
--  À exécuter dans Supabase (SQL Editor) ou via `supabase db push`
-- =====================================================================

-- ---------------------------------------------------------------------
-- Profils (nom affiché de chaque parent)
-- ---------------------------------------------------------------------
create table public.profiles (
  id           uuid primary key references auth.users (id) on delete cascade,
  display_name text not null default '',
  updated_at   timestamptz not null default now()
);

-- Création automatique du profil à l'inscription
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer set search_path = public
as $$
begin
  insert into public.profiles (id, display_name)
  values (
    new.id,
    coalesce(nullif(new.raw_user_meta_data ->> 'display_name', ''), split_part(new.email, '@', 1))
  );
  return new;
end;
$$;

create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

-- ---------------------------------------------------------------------
-- Journaux
-- ---------------------------------------------------------------------
create table public.journals (
  id          uuid primary key default gen_random_uuid(),
  name        text not null,
  child_name  text not null default '',
  created_by  uuid not null default auth.uid() references public.profiles (id) on delete cascade,
  share_token text unique,
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now(),
  deleted_at  timestamptz
);

create table public.journal_members (
  journal_id uuid not null references public.journals (id) on delete cascade,
  user_id    uuid not null references public.profiles (id) on delete cascade,
  role       text not null default 'member' check (role in ('owner', 'member')),
  joined_at  timestamptz not null default now(),
  primary key (journal_id, user_id)
);

create index journal_members_user_idx on public.journal_members (user_id);

-- ---------------------------------------------------------------------
-- Réveils
-- ---------------------------------------------------------------------
create table public.wakeups (
  id          uuid primary key default gen_random_uuid(),
  journal_id  uuid not null references public.journals (id) on delete cascade,
  woke_at     timestamptz not null,
  reasons     text[] not null default '{}',
  actions     text[] not null default '{}',
  comment     text not null default '',
  created_by  uuid not null default auth.uid() references public.profiles (id),
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now(),
  deleted_at  timestamptz
);

create index wakeups_journal_updated_idx on public.wakeups (journal_id, updated_at);
create index wakeups_journal_woke_idx on public.wakeups (journal_id, woke_at);

-- ---------------------------------------------------------------------
-- Fonctions utilitaires
-- ---------------------------------------------------------------------
create or replace function public.is_journal_member(p_journal_id uuid)
returns boolean
language sql
stable
security definer set search_path = public
as $$
  select exists (
    select 1 from public.journal_members
    where journal_id = p_journal_id and user_id = auth.uid()
  );
$$;

create or replace function public.is_journal_owner(p_journal_id uuid)
returns boolean
language sql
stable
security definer set search_path = public
as $$
  select exists (
    select 1 from public.journal_members
    where journal_id = p_journal_id and user_id = auth.uid() and role = 'owner'
  );
$$;

create or replace function public.shares_journal_with(p_user_id uuid)
returns boolean
language sql
stable
security definer set search_path = public
as $$
  select exists (
    select 1
    from public.journal_members a
    join public.journal_members b on a.journal_id = b.journal_id
    where a.user_id = auth.uid() and b.user_id = p_user_id
  );
$$;

-- updated_at toujours horodaté par le serveur (base de la synchronisation)
create or replace function public.touch_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at := now();
  if tg_op = 'INSERT' then
    -- l'auteur est toujours l'utilisateur connecté. Lors d'un upsert qui aboutit
    -- à une mise à jour, la branche UPDATE ci-dessous restaure l'auteur d'origine.
    new.created_by := coalesce(auth.uid(), new.created_by);
  else
    -- l'auteur et la date de création ne changent jamais
    new.created_by := old.created_by;
    new.created_at := old.created_at;
  end if;
  return new;
end;
$$;

create trigger journals_touch before insert or update on public.journals
  for each row execute function public.touch_updated_at();

create trigger wakeups_touch before insert or update on public.wakeups
  for each row execute function public.touch_updated_at();

-- (fonction dédiée : profiles n'a pas de created_by)
create or replace function public.touch_updated_at_profile()
returns trigger language plpgsql as $$
begin
  new.updated_at := now();
  return new;
end;
$$;

create trigger profiles_touch before update on public.profiles
  for each row execute function public.touch_updated_at_profile();

-- Seul le propriétaire peut supprimer (soft delete) ou changer le lien de partage
create or replace function public.guard_journal_update()
returns trigger
language plpgsql
as $$
begin
  if (new.deleted_at is distinct from old.deleted_at
      or new.share_token is distinct from old.share_token)
     and not public.is_journal_owner(old.id) then
    raise exception 'Seul le propriétaire du journal peut faire cette action'
      using errcode = '42501';
  end if;
  return new;
end;
$$;

create trigger journals_guard before update on public.journals
  for each row execute function public.guard_journal_update();

-- Le créateur devient automatiquement propriétaire
create or replace function public.add_journal_owner()
returns trigger
language plpgsql
security definer set search_path = public
as $$
begin
  insert into public.journal_members (journal_id, user_id, role)
  values (new.id, new.created_by, 'owner')
  on conflict do nothing;
  return new;
end;
$$;

create trigger journals_add_owner after insert on public.journals
  for each row execute function public.add_journal_owner();

-- Rejoindre un journal via un lien de partage
create or replace function public.join_journal(p_token text)
returns uuid
language plpgsql
security definer set search_path = public
as $$
declare
  v_journal_id uuid;
begin
  if auth.uid() is null then
    raise exception 'Non authentifié' using errcode = '42501';
  end if;

  select id into v_journal_id
  from public.journals
  where share_token = p_token and deleted_at is null;

  if v_journal_id is null then
    raise exception 'Lien d''invitation invalide ou expiré' using errcode = 'P0002';
  end if;

  insert into public.journal_members (journal_id, user_id, role)
  values (v_journal_id, auth.uid(), 'member')
  on conflict do nothing;

  return v_journal_id;
end;
$$;

-- Aperçu d'une invitation (nom du journal) avant de rejoindre
create or replace function public.invitation_preview(p_token text)
returns table (journal_name text, child_name text)
language sql
stable
security definer set search_path = public
as $$
  select name, child_name from public.journals
  where share_token = p_token and deleted_at is null;
$$;

grant execute on function public.join_journal(text) to authenticated;
grant execute on function public.invitation_preview(text) to authenticated;

-- ---------------------------------------------------------------------
-- Row Level Security
-- ---------------------------------------------------------------------
alter table public.profiles        enable row level security;
alter table public.journals        enable row level security;
alter table public.journal_members enable row level security;
alter table public.wakeups         enable row level security;

-- profiles
create policy "profils visibles : soi et co-membres" on public.profiles
  for select to authenticated
  using (id = auth.uid() or public.shares_journal_with(id));

create policy "profil modifiable par soi" on public.profiles
  for update to authenticated
  using (id = auth.uid()) with check (id = auth.uid());

-- journals
create policy "journaux visibles par les membres" on public.journals
  for select to authenticated
  using (created_by = auth.uid() or public.is_journal_member(id));

create policy "création de journal" on public.journals
  for insert to authenticated
  with check (created_by = auth.uid());

create policy "modification par les membres" on public.journals
  for update to authenticated
  using (public.is_journal_member(id))
  with check (public.is_journal_member(id));

-- journal_members (insertion uniquement via triggers / join_journal)
create policy "membres visibles par les membres" on public.journal_members
  for select to authenticated
  using (public.is_journal_member(journal_id));

create policy "quitter ou retirer un membre" on public.journal_members
  for delete to authenticated
  using (
    (user_id = auth.uid() and role <> 'owner')
    or (public.is_journal_owner(journal_id) and user_id <> auth.uid())
  );

-- wakeups
create policy "réveils visibles par les membres" on public.wakeups
  for select to authenticated
  using (public.is_journal_member(journal_id));

create policy "création de réveil par un membre" on public.wakeups
  for insert to authenticated
  with check (public.is_journal_member(journal_id) and created_by = auth.uid());

create policy "modification de réveil par un membre" on public.wakeups
  for update to authenticated
  using (public.is_journal_member(journal_id))
  with check (public.is_journal_member(journal_id));
