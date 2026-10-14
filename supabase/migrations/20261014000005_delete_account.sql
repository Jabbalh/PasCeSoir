-- =====================================================================
--  Suppression de compte
--  - Journaux dont l'utilisateur est propriétaire : supprimés pour tous
--    (membres, réveils et options en cascade)
--  - Journaux dont il est simple membre : seule l'adhésion est supprimée ;
--    les réveils qu'il y a saisis sont conservés, sans auteur
--  - Compte, profil, rôle admin, invitations créées : supprimés
-- =====================================================================

-- L'auteur d'un réveil devient vide quand son compte est supprimé
alter table public.wakeups alter column created_by drop not null;
alter table public.wakeups drop constraint wakeups_created_by_fkey;
alter table public.wakeups
  add constraint wakeups_created_by_fkey
  foreign key (created_by) references public.profiles (id) on delete set null;

-- L'auteur reste immuable, sauf effacement automatique par la contrainte
-- « on delete set null » (mise à jour déclenchée en cascade, donc pg_trigger_depth() > 1)
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
    if not (new.created_by is null and pg_trigger_depth() > 1) then
      new.created_by := old.created_by;
    end if;
    new.created_at := old.created_at;
  end if;
  return new;
end;
$$;

-- ---------------------------------------------------------------------
-- Aperçu avant suppression : journaux possédés et nombre d'autres membres
-- ---------------------------------------------------------------------
create or replace function public.account_deletion_preview()
returns table (journal_id uuid, journal_name text, other_members integer)
language sql
stable
security definer set search_path = public
as $$
  select
    j.id,
    j.name,
    (select count(*)::integer from public.journal_members m
     where m.journal_id = j.id and m.user_id <> auth.uid())
  from public.journals j
  where j.created_by = auth.uid() and j.deleted_at is null
  order by j.name;
$$;

-- ---------------------------------------------------------------------
-- Suppression définitive du compte de l'utilisateur connecté
-- ---------------------------------------------------------------------
create or replace function public.delete_my_account()
returns void
language plpgsql
security definer set search_path = public
as $$
declare
  v_user uuid := auth.uid();
begin
  if v_user is null then
    raise exception 'Non authentifié' using errcode = '42501';
  end if;

  -- Journaux possédés : supprimés pour tous les membres
  delete from public.journals where created_by = v_user;

  -- Compte : cascade sur le profil, les adhésions, le rôle admin et les invitations créées ;
  -- les réveils saisis dans les journaux des autres perdent seulement leur auteur
  delete from auth.users where id = v_user;
end;
$$;

revoke execute on function public.account_deletion_preview() from public, anon;
revoke execute on function public.delete_my_account() from public, anon;
grant execute on function public.account_deletion_preview() to authenticated;
grant execute on function public.delete_my_account() to authenticated;
