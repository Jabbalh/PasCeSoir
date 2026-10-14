    -- =====================================================================
    --  Type de réveil : lever du matin ou réveil nocturne (vide par défaut)
    -- =====================================================================

    alter table public.wakeups
      add column wake_type text check (wake_type in ('lever', 'nocturne'));
