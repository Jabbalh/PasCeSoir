-- =====================================================================
--  Inscription sur invitation uniquement
--  Un compte ne peut être créé que :
--   - avec un jeton d'invitation valide (lien de partage actif d'un journal),
--   - ou si l'email figure dans public.signup_allowlist (géré depuis le dashboard).
--  La personne invitée rejoint automatiquement le journal à l'inscription.
-- =====================================================================

-- Liste des emails autorisés à s'inscrire sans invitation
-- (à remplir depuis Supabase : Table Editor -> signup_allowlist)
create table public.signup_allowlist (
  email      text primary key check (email = lower(email)),
  note       text,
  created_at timestamptz not null default now()
);

-- RLS activée sans politique : invisible depuis l'application
alter table public.signup_allowlist enable row level security;
revoke all on public.signup_allowlist from anon, authenticated;

-- ---------------------------------------------------------------------
-- Contrôle avant création du compte
-- ---------------------------------------------------------------------
create or replace function public.guard_signup()
returns trigger
language plpgsql
security definer set search_path = public
as $$
declare
  v_token text := nullif(new.raw_user_meta_data ->> 'invite_token', '');
begin
  if exists (select 1 from public.signup_allowlist where email = lower(new.email)) then
    return new;
  end if;

  if v_token is not null and exists (
    select 1 from public.journals where share_token = v_token and deleted_at is null
  ) then
    return new;
  end if;

  raise exception 'Inscription sur invitation uniquement' using errcode = 'P0001';
end;
$$;

create trigger before_auth_user_created
  before insert on auth.users
  for each row execute function public.guard_signup();

-- ---------------------------------------------------------------------
-- Profil + adhésion automatique au journal de l'invitation
-- ---------------------------------------------------------------------
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer set search_path = public
as $$
declare
  v_token text := nullif(new.raw_user_meta_data ->> 'invite_token', '');
begin
  insert into public.profiles (id, display_name)
  values (
    new.id,
    coalesce(nullif(new.raw_user_meta_data ->> 'display_name', ''), split_part(new.email, '@', 1))
  );

  if v_token is not null then
    insert into public.journal_members (journal_id, user_id, role)
    select id, new.id, 'member'
    from public.journals
    where share_token = v_token and deleted_at is null
    on conflict do nothing;
  end if;

  return new;
end;
$$;
