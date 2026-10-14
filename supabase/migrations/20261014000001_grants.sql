-- =====================================================================
--  Droits explicites
--  Les projets Supabase récents n'accordent plus automatiquement de
--  privilèges aux rôles anon / authenticated sur les nouvelles tables.
--  Les politiques RLS restent la barrière principale ; ces GRANT ne font
--  qu'autoriser l'accès à la table, ligne par ligne filtrée par RLS.
-- =====================================================================

grant usage on schema public to authenticated;

grant select, update                 on public.profiles        to authenticated;
grant select, insert, update         on public.journals        to authenticated;
grant select, delete                 on public.journal_members to authenticated;
grant select, insert, update         on public.wakeups         to authenticated;

-- Aucun accès pour les visiteurs non connectés
revoke all on public.profiles, public.journals, public.journal_members, public.wakeups from anon;

-- Fonctions : réservées aux utilisateurs connectés
revoke execute on function public.join_journal(text)        from public, anon;
revoke execute on function public.invitation_preview(text)  from public, anon;
grant  execute on function public.join_journal(text)        to authenticated;
grant  execute on function public.invitation_preview(text)  to authenticated;

-- Fonctions utilisées par les politiques RLS
revoke execute on function public.is_journal_member(uuid)   from public, anon;
revoke execute on function public.is_journal_owner(uuid)    from public, anon;
revoke execute on function public.shares_journal_with(uuid) from public, anon;
grant  execute on function public.is_journal_member(uuid)   to authenticated;
grant  execute on function public.is_journal_owner(uuid)    to authenticated;
grant  execute on function public.shares_journal_with(uuid) to authenticated;
