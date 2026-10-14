# Base de données (Supabase / Postgres)

Toute la logique de sécurité est dans la base : **Row Level Security** sur chaque table, triggers et fonctions `security definer`. Le rôle `anon` n'a accès à aucune table.

## 1. Schéma

```
auth.users ──1:1── profiles ──┬──< journal_members >── journals ──┬──< wakeups
                              │                                   └──< journal_options
                              ├──1:1── app_admins
                              └──< app_invites (created_by, used_by)

signup_allowlist (indépendante)
```

### `profiles`

| Colonne | Type | Remarque |
|---|---|---|
| `id` | uuid PK | = `auth.users.id`, cascade à la suppression |
| `display_name` | text | nom affiché ; initialisé depuis les métadonnées d'inscription ou la partie locale de l'email |
| `updated_at` | timestamptz | |

Créé automatiquement par le trigger `on_auth_user_created` → `handle_new_user()`.

### `journals`

| Colonne | Type | Remarque |
|---|---|---|
| `id` | uuid PK | généré côté client |
| `name` | text | |
| `child_name` | text | |
| `created_by` | uuid → profiles | propriétaire ; cascade |
| `share_token` | text unique | lien de partage actif (null = désactivé) |
| `created_at`, `updated_at`, `deleted_at` | timestamptz | soft delete |

### `journal_members`

| Colonne | Type | Remarque |
|---|---|---|
| `journal_id`, `user_id` | PK composite | cascade |
| `role` | text | `owner` ou `member` |
| `joined_at` | timestamptz | |

Le créateur est ajouté comme `owner` par le trigger `journals_add_owner`. L'insertion ne se fait que par triggers ou par `join_journal` (aucune politique d'insertion).

### `wakeups`

| Colonne | Type | Remarque |
|---|---|---|
| `id` | uuid PK | généré côté client |
| `journal_id` | uuid → journals | cascade |
| `woke_at` | timestamptz | date/heure du réveil |
| `wake_type` | text, nullable | `lever` ou `nocturne` ; vide par défaut |
| `reason_ids` | uuid[] | identifiants de `journal_options` (`kind = 'reason'`) |
| `action_ids` | uuid[] | identifiants de `journal_options` (`kind = 'action'`) |
| `comment` | text | HTML du texte riche |
| `created_by` | uuid → profiles, nullable | auteur ; `set null` si le compte est supprimé |
| `created_at`, `updated_at`, `deleted_at` | timestamptz | soft delete |

Index : `(journal_id, updated_at)` pour la synchro, `(journal_id, woke_at)`.

### `journal_options`

| Colonne | Type | Remarque |
|---|---|---|
| `id` | uuid PK | |
| `journal_id` | uuid → journals | cascade |
| `kind` | text | `reason` ou `action` |
| `label` | text | renommer met à jour tout l'historique (référence par id) |
| `position` | integer | ordre d'affichage |
| `created_at`, `updated_at` | timestamptz | |
| `deleted_at` | timestamptz | option **archivée** (masquée du choix, conservée pour l'historique) |

### `app_admins`

`user_id` (PK → profiles, cascade), `created_at`. Lecture de sa propre ligne uniquement ; aucune écriture depuis l'application.

### `app_invites`

| Colonne | Remarque |
|---|---|
| `id`, `token` (unique) | jeton aléatoire 144 bits, URL-safe |
| `note` | « Pour qui ? » |
| `created_by` | admin créateur (défaut `auth.uid()`) |
| `created_at`, `expires_at` | validité (défaut 7 jours) |
| `revoked_at` | révocation |
| `used_by`, `used_at` | consommation (usage unique) |

### `signup_allowlist`

`email` (PK, en minuscules), `note`, `created_at`. Invisible depuis l'application (RLS sans politique) : à gérer depuis le Table Editor de Supabase.

## 2. Triggers

| Trigger | Table | Rôle |
|---|---|---|
| `before_auth_user_created` → `guard_signup()` | `auth.users` | refuse l'inscription hors invitation |
| `on_auth_user_created` → `handle_new_user()` | `auth.users` | crée le profil, fait rejoindre le journal (lien de partage), consomme l'invitation à l'app |
| `journals_touch`, `wakeups_touch` → `touch_updated_at()` | | `updated_at = now()` ; `created_by` = utilisateur connecté à l'insertion, puis immuable (sauf mise à `null` par la suppression du compte) ; `created_at` immuable |
| `journal_options_touch`, `profiles_touch` | | `updated_at = now()` |
| `journals_guard` → `guard_journal_update()` | `journals` | seul le propriétaire peut changer `deleted_at` ou `share_token` (erreur `42501`) |
| `journals_add_owner` → `add_journal_owner()` | `journals` | ajoute le créateur comme `owner` |

## 3. Sécurité (RLS)

| Table | Lecture | Insertion | Modification | Suppression |
|---|---|---|---|---|
| `profiles` | soi, co-membres d'un journal, admins | — (trigger) | soi | — |
| `journals` | créateur ou membre | `created_by = auth.uid()` | membres (+ garde propriétaire) | — (soft delete) |
| `journal_members` | membres du journal | — (trigger / RPC) | — | soi si non propriétaire ; propriétaire pour les autres |
| `wakeups` | membres | membre, `created_by = auth.uid()` | membres | — (soft delete) |
| `journal_options` | membres | membres | membres | — (archivage) |
| `app_admins` | sa propre ligne | — | — | — |
| `app_invites` | admins | admins | admins | — |
| `signup_allowlist` | — | — | — | — |

Fonctions d'aide utilisées par les politiques (`security definer`, exécutables par `authenticated` uniquement) : `is_journal_member(uuid)`, `is_journal_owner(uuid)`, `shares_journal_with(uuid)`, `is_app_admin()`.

Les `GRANT` explicites (migration `…000001_grants.sql`) ne font qu'ouvrir l'accès aux tables ; le filtrage ligne à ligne reste assuré par RLS.

## 4. Fonctions RPC

| Fonction | Appelable par | Rôle |
|---|---|---|
| `invitation_preview(token)` | authenticated | nom du journal et prénom de l'enfant d'un lien de partage actif |
| `join_journal(token)` | authenticated | rejoint le journal du lien comme `member`, renvoie son id |
| `app_invite_is_valid(token)` | anon, authenticated | indique seulement si une invitation à l'app est utilisable |
| `account_deletion_preview()` | authenticated | journaux possédés et nombre d'autres membres |
| `delete_my_account()` | authenticated | supprime les journaux possédés puis le compte (cascades) |

## 5. Processus

### Inscription sur invitation

`guard_signup()` accepte la création d'un compte si l'une de ces conditions est vraie :

1. l'email est dans `signup_allowlist` ;
2. la métadonnée `invite_token` correspond au `share_token` d'un journal non supprimé ;
3. la métadonnée `app_invite` correspond à une invitation non utilisée, non révoquée et non expirée.

Sinon : exception `Inscription sur invitation uniquement` (Supabase Auth la renvoie comme « Database error saving new user », traduit par `errorMessage()`).

### Suppression de compte

1. Suppression des journaux dont l'utilisateur est le créateur → cascade sur membres, réveils et options (pour tous).
2. Suppression de `auth.users` → cascade sur le profil, les adhésions, le rôle admin et les invitations créées ; les réveils saisis dans les journaux des autres passent à `created_by = null`.

### Administrateurs

Désigner un administrateur (SQL Editor) :

```sql
insert into public.app_admins (user_id)
select id from auth.users where email = '<email>';
```

Autoriser un email à s'inscrire sans invitation :

```sql
insert into public.signup_allowlist (email, note) values ('<email en minuscules>', '<note>');
```

## 6. Migrations

À appliquer **dans l'ordre**. Ne jamais modifier une migration déjà appliquée : en créer une nouvelle.

| Fichier | Contenu |
|---|---|
| `20261014000000_init.sql` | profils, journaux, membres, réveils, fonctions d'aide, triggers, partage, RLS |
| `20261014000001_grants.sql` | droits explicites `authenticated`, aucun accès `anon` |
| `20261014000002_journal_options.sql` | raisons / actions par journal ; réveils par identifiants (reprise des libellés) |
| `20261014000003_invite_only_signup.sql` | inscription sur invitation, `signup_allowlist`, adhésion automatique |
| `20261014000004_admin_app_invites.sql` | administrateurs, invitations à l'application |
| `20261014000005_delete_account.sql` | auteur des réveils nullable, suppression de compte |
| `20261014000006_wakeup_type.sql` | type de réveil (`lever` / `nocturne`) |

## 7. Base locale (IndexedDB)

Voir [documentation technique § 6](technique.md#6-données-locales-dexie). Les tables locales reprennent les colonnes du serveur, plus `_dirty` et `_lmod`. `members` est une vue dénormalisée (`journal_members` + `profiles.display_name`).
