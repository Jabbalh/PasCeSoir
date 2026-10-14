-- =====================================================================
--  Administrateurs et invitations à l'application
--  - app_admins : liste des administrateurs (modifiable uniquement depuis Supabase)
--  - app_invites : liens d'inscription à usage unique, créés par un admin,
--    qui ne font rejoindre aucun journal
--
--  Pour désigner un administrateur (SQL Editor) :
--    insert into public.app_admins (user_id)
--    select id from auth.users where email = '<email de l''admin>';
-- =====================================================================

create table public.app_admins (
  user_id    uuid primary key references public.profiles (id) on delete cascade,
  created_at timestamptz not null default now()
);

alter table public.app_admins enable row level security;

-- Chacun peut seulement savoir s'il est lui-même admin ; aucune écriture depuis l'app
create policy "un admin voit son propre rôle" on public.app_admins
  for select to authenticated
  using (user_id = auth.uid());

grant select on public.app_admins to authenticated;
revoke all on public.app_admins from anon;

create or replace function public.is_app_admin()
returns boolean
language sql
stable
security definer set search_path = public
as $$
  select exists (select 1 from public.app_admins where user_id = auth.uid());
$$;

revoke execute on function public.is_app_admin() from public, anon;
grant execute on function public.is_app_admin() to authenticated;

-- Les admins voient tous les profils (pour savoir qui a utilisé une invitation)
create policy "profils visibles par les admins" on public.profiles
  for select to authenticated
  using (public.is_app_admin());

-- ---------------------------------------------------------------------
-- Invitations à l'application
-- ---------------------------------------------------------------------
create table public.app_invites (
  id          uuid primary key default gen_random_uuid(),
  token       text not null unique,
  note        text not null default '',
  created_by  uuid not null default auth.uid() references public.profiles (id) on delete cascade,
  created_at  timestamptz not null default now(),
  expires_at  timestamptz not null default now() + interval '7 days',
  revoked_at  timestamptz,
  used_by     uuid references public.profiles (id) on delete set null,
  used_at     timestamptz
);

alter table public.app_invites enable row level security;

create policy "invitations visibles par les admins" on public.app_invites
  for select to authenticated
  using (public.is_app_admin());

create policy "invitations créées par les admins" on public.app_invites
  for insert to authenticated
  with check (public.is_app_admin() and created_by = auth.uid());

create policy "invitations modifiées par les admins" on public.app_invites
  for update to authenticated
  using (public.is_app_admin())
  with check (public.is_app_admin());

grant select, insert, update on public.app_invites to authenticated;
revoke all on public.app_invites from anon;

-- Vérification d'un lien avant inscription (appelable sans compte ; ne révèle que oui/non)
create or replace function public.app_invite_is_valid(p_token text)
returns boolean
language sql
stable
security definer set search_path = public
as $$
  select exists (
    select 1 from public.app_invites
    where token = p_token and used_at is null and revoked_at is null and expires_at > now()
  );
$$;

grant execute on function public.app_invite_is_valid(text) to anon, authenticated;

-- ---------------------------------------------------------------------
-- Contrôle d'inscription : journal, invitation à l'app ou liste blanche
-- ---------------------------------------------------------------------
create or replace function public.guard_signup()
returns trigger
language plpgsql
security definer set search_path = public
as $$
declare
  v_journal_token text := nullif(new.raw_user_meta_data ->> 'invite_token', '');
  v_app_token     text := nullif(new.raw_user_meta_data ->> 'app_invite', '');
begin
  if exists (select 1 from public.signup_allowlist where email = lower(new.email)) then
    return new;
  end if;

  if v_journal_token is not null and exists (
    select 1 from public.journals where share_token = v_journal_token and deleted_at is null
  ) then
    return new;
  end if;

  if v_app_token is not null and public.app_invite_is_valid(v_app_token) then
    return new;
  end if;

  raise exception 'Inscription sur invitation uniquement' using errcode = 'P0001';
end;
$$;

-- Profil, adhésion au journal de l'invitation, consommation de l'invitation à l'app
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer set search_path = public
as $$
declare
  v_journal_token text := nullif(new.raw_user_meta_data ->> 'invite_token', '');
  v_app_token     text := nullif(new.raw_user_meta_data ->> 'app_invite', '');
begin
  insert into public.profiles (id, display_name)
  values (
    new.id,
    coalesce(nullif(new.raw_user_meta_data ->> 'display_name', ''), split_part(new.email, '@', 1))
  );

  if v_journal_token is not null then
    insert into public.journal_members (journal_id, user_id, role)
    select id, new.id, 'member'
    from public.journals
    where share_token = v_journal_token and deleted_at is null
    on conflict do nothing;
  end if;

  if v_app_token is not null then
    update public.app_invites
    set used_by = new.id, used_at = now()
    where token = v_app_token and used_at is null;
  end if;

  return new;
end;
$$;
