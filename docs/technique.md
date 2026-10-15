# Documentation technique

## 1. Vue d'ensemble

```
 Téléphone (PWA, SPA Nuxt)                                  Supabase
┌──────────────────────────────────────────┐        ┌──────────────────────────┐
│ Pages / composants Vue (Nuxt UI)         │        │ Auth (email + mot de     │
│        │  lecture réactive (liveQuery)   │        │ passe, PKCE)             │
│        ▼                                 │        │                          │
│ IndexedDB (Dexie) : pascesoir-<userId>   │ upsert │ Postgres + RLS           │
│  journals, options, wakeups, members ... │ ─────► │  journals, wakeups,      │
│        ▲  écriture locale (_dirty = 1)   │ ◄───── │  journal_options, ...    │
│        │                                 │ select │                          │
│ useSync : push / pull                    │        │ Fonctions RPC (join,     │
│ Service worker (Workbox) : cache app     │        │ invitations, suppression)│
└──────────────────────────────────────────┘        └──────────────────────────┘
        hébergé en statique sur Vercel
```

- **Local-first** : l'interface lit et écrit uniquement dans IndexedDB. La synchronisation avec Supabase se fait en arrière-plan.
- **Pas de backend applicatif** : la sécurité repose entièrement sur Postgres (RLS, triggers, fonctions `security definer`).
- **SPA statique** (`ssr: false`, preset Nitro `static`) déployée sur Vercel.

## 2. Stack

| Couche | Technologie |
|---|---|
| Framework | Nuxt 4 (SPA), Vue 3, TypeScript |
| UI | Nuxt UI 4, Tailwind CSS 4, icônes Lucide (Iconify, embarquées) |
| Données locales | Dexie 4 (IndexedDB) |
| Backend | Supabase : Auth + Postgres (`@supabase/supabase-js` 2) |
| PWA | `@vite-pwa/nuxt` (Workbox), `@vite-pwa/assets-generator` |
| Hébergement | Vercel (site statique) |

## 3. Structure du projet

```
app/
├── app.vue, app.config.ts        # racine, couleurs Nuxt UI (primary indigo, neutral slate)
├── assets/css/main.css
├── components/
│   ├── ApproachCard.vue          # carte d'une démarche dans la liste
│   ├── ColumnChart.vue           # histogramme vertical (simple ou empilé) + frise de bandes
│   ├── OptionsEditor.vue         # gestion des raisons / actions d'un journal
│   ├── PwaPrompts.vue            # bandeaux mise à jour / installation / hors ligne
│   ├── RichTextEditor.vue        # éditeur du commentaire
│   ├── SyncStatus.vue            # indicateur de synchronisation (en-tête)
│   ├── TagPicker.vue             # choix multiple + création d'option
│   └── WakeupCard.vue            # carte d'un réveil dans la liste
├── composables/
│   ├── useAuth.ts                # session, rôle admin, inscription, suppression de compte
│   ├── useDb.ts                  # base Dexie de l'utilisateur + useLiveQuery
│   ├── useJournal.ts             # actions d'écriture + requêtes réactives
│   └── useSync.ts                # synchronisation IndexedDB <-> Supabase
├── layouts/  default.vue (en-tête + navigation du journal), auth.vue
├── middleware/auth.global.ts     # redirections connexion / admin
├── pages/                        # voir § 4
├── plugins/supabase.client.ts    # client Supabase (provide $supabase)
└── utils/
    ├── db.ts                     # types, constantes (WAKE_TYPES, APPROACH_KINDS, DAY_PERIODS), schéma Dexie
    ├── errors.ts                 # traduction des messages d'erreur
    ├── night.ts                  # notion de « nuit », formats de date
    ├── approach.ts               # état et libellés des démarches
    └── token.ts                  # jetons d'invitation, partage natif / copie
supabase/migrations/              # scripts SQL, à appliquer dans l'ordre
docs/                             # cette documentation
nuxt.config.ts, vercel.json, pwa-assets.config.ts
```

Les fonctions de `utils/` et `composables/` sont auto-importées par Nuxt.

## 4. Routes

| Route | Fichier | Accès |
|---|---|---|
| `/` | `pages/index.vue` | connecté |
| `/journal/:id` | `pages/journal/[id]/index.vue` | connecté |
| `/journal/:id/reveil/:wid` (`nouveau` pour une création) | `pages/journal/[id]/reveil/[wid].vue` | connecté |
| `/journal/:id/stats` | `pages/journal/[id]/stats.vue` | connecté |
| `/journal/:id/demarches` | `pages/journal/[id]/demarches/index.vue` | connecté |
| `/journal/:id/demarches/:aid` (`nouveau` pour une création) | `pages/journal/[id]/demarches/[aid].vue` | connecté |
| `/journal/:id/reglages` | `pages/journal/[id]/reglages.vue` | connecté |
| `/rejoindre/:token` | `pages/rejoindre/[token].vue` | connecté (sinon redirigé vers `/connexion?redirect=…`) |
| `/profil` | `pages/profil.vue` | connecté |
| `/admin` | `pages/admin.vue` | administrateur |
| `/connexion` | `pages/connexion.vue` | public |
| `/inscription/:token` | `pages/inscription/[token].vue` | public |
| `/nouveau-mot-de-passe` | `pages/nouveau-mot-de-passe.vue` | public |

`middleware/auth.global.ts` : redirige vers `/connexion` (avec `redirect`) si non connecté, renvoie un utilisateur connecté hors de `/connexion`, et bloque `/admin` aux non-administrateurs. Le contrôle admin côté client n'est qu'ergonomique : les droits sont vérifiés par la base.

## 5. Authentification (`useAuth`)

- Client Supabase en flux **PKCE**, session persistée, rafraîchissement automatique.
- **Hors ligne** : le dernier utilisateur est mis en cache dans `localStorage` (`pcs:user`), ainsi que le rôle admin (`pcs:admin`), pour que l'application démarre sans réseau.
- **Inscription** : `supabase.auth.signUp` avec des métadonnées `display_name`, `invite_token` (lien de journal) ou `app_invite` (invitation admin). Le contrôle est fait côté base par le trigger `guard_signup` (voir [base de données](base-de-donnees.md#inscription-sur-invitation)).
- **Suppression de compte** : RPC `delete_my_account`, puis déconnexion locale, suppression de la base IndexedDB et des clés `pcs:*`.
- Clés `localStorage` utilisées : `pcs:user`, `pcs:admin`, `pcs:lastJournal`.

## 6. Données locales (Dexie)

Une base IndexedDB **par utilisateur** : `pascesoir-<userId>` (pas de mélange entre comptes sur un même appareil).

| Table | Clé | Index | Contenu |
|---|---|---|---|
| `journals` | `id` | `_dirty` | journaux |
| `options` | `id` | `journal_id`, `_dirty` | raisons / actions |
| `wakeups` | `id` | `journal_id`, `[journal_id+woke_at]`, `_dirty` | réveils |
| `members` | `key` (`<journal_id>:<user_id>`) | `journal_id` | membres + nom affiché (lecture seule, tiré du serveur) |
| `approaches` | `id` | `journal_id`, `_dirty` | démarches |
| `meta` | `key` | — | curseurs de synchro (`cursor:<journalId>`, `ocursor:<journalId>`, `acursor:<journalId>`) |

Champs techniques sur les lignes synchronisées :

- `_dirty` : `1` = modification locale non envoyée.
- `_lmod` : horodatage local de la dernière modification ; permet de ne pas « nettoyer » une ligne modifiée pendant son envoi.

Versions du schéma (`utils/db.ts`) : v1 initial, v2 ajout des options (rechargement des réveils), v3 rechargement complet après migration des libellés vers les identifiants, v4 ajout des démarches. Les modifications non envoyées sont toujours conservées lors d'une montée de version.

> Ajouter un champ **non indexé** ne nécessite pas de nouvelle version Dexie : il suffit de tolérer son absence sur les lignes existantes (ex. `wake_type ?? null`).

Lecture réactive : `useLiveQuery(query, initial, deps)` s'appuie sur `liveQuery` de Dexie ; toute écriture locale (y compris par la synchro) met l'interface à jour.

## 7. Synchronisation (`useSync`)

### Principes

- Toute écriture est **locale d'abord** (`_dirty = 1`), avec des identifiants **UUID générés côté client** : création possible hors ligne, envoi idempotent par `upsert`.
- `updated_at` est **toujours horodaté par le serveur** (trigger) et sert de curseur de lecture.
- Suppression = **soft delete** (`deleted_at`) pour propager l'effacement aux autres appareils.
- **Conflits** : la dernière écriture envoyée l'emporte ; une ligne locale `_dirty` n'est **jamais** écrasée par une donnée distante.

### Déroulé d'une synchronisation

1. **Push** journaux (un par un ; `deleted_at` n'est envoyé que par le propriétaire, sinon refus serveur).
2. **Push** options, réveils puis démarches, par lots de 100. Si un lot est refusé pour un problème de droits (`42501`, `PGRST301`, ex. journal quitté), les lignes sont renvoyées une à une et les lignes refusées sont abandonnées.
3. Purge locale des réveils et démarches supprimés et confirmés.
4. **Pull** journaux + membres : journaux supprimés ou dont on n'est plus membre → effacés localement avec leurs réveils, options, démarches et curseurs.
5. **Pull** options, réveils puis démarches de chaque journal depuis le curseur, avec **60 s de recouvrement** (lignes commitées en retard), pagination par 500 triée par `(updated_at, id)`.
   - Réveil supprimé → effacé localement.
   - Option archivée → conservée (son libellé reste affiché sur les anciens réveils).
   - Démarche supprimée → effacée localement.

### Déclencheurs

Démarrage, évènement `online`, retour au premier plan (`visibilitychange`), toutes les 30 s (si visible), et après chaque écriture (`schedule()`, debounce 800 ms ; 7 s après une suppression pour laisser le temps d'« Annuler »). Les appels concurrents sont fusionnés.

### Champs synchronisés

- Réveils : `WAKEUP_FIELDS` (`id, journal_id, woke_at, wake_type, reason_ids, action_ids, comment, created_by, created_at, deleted_at`).
- Options : `OPTION_FIELDS` (`id, journal_id, kind, label, position, created_at, deleted_at`).
- Démarches : `APPROACH_FIELDS` (`id, journal_id, kind, label, start_date, end_date, periods, comment, created_by, created_at, deleted_at`).

> ⚠️ Ajouter un champ à ces listes **avant** d'avoir appliqué la migration serveur fait échouer l'envoi (colonne inconnue). Toujours déployer la migration en premier.

### Opérations en ligne uniquement

Partage (`share_token`), retrait d'un membre / quitter, rejoindre (`join_journal`), profil, administration, inscription et suppression de compte appellent Supabase directement, puis lancent une synchronisation.

## 8. Règles métier dans le code

| Règle | Où |
|---|---|
| Une nuit = 14h → 14h (`NIGHT_PIVOT_HOUR`) ; clé de nuit = date du soir | `utils/night.ts` |
| Semaine commençant le lundi (`weekKey`), mois (`monthKey`) | `utils/night.ts` |
| Types de réveil `lever` / `nocturne`, libellés et icônes (`WAKE_TYPES`) | `utils/db.ts` |
| Création de journal sans raisons ni actions par défaut | `useJournalActions.createJournal` |
| Ajout d'une option du même nom qu'une option archivée → restauration | `useJournalActions.addOption` |
| Réordonnancement : seules les positions modifiées sont envoyées | `useJournalActions.reorderOptions` |
| Anti double-appui du bouton RÉVEIL (2 s) | `pages/journal/[id]/index.vue` |
| Réveil « À compléter » = ni raison, ni action, ni commentaire | `components/WakeupCard.vue` |
| Statistiques (répartition par type, séries empilées, top raisons, heures) | `pages/journal/[id]/stats.vue` |
| Démarche en cours / à venir / terminée (date de fin incluse), rattachement aux nuits par la date du soir | `utils/approach.ts` |
| Effet des démarches : réveils nocturnes par nuit pendant vs 30 nuits avant (nuit en cours exclue) ; frise alignée sur l'histogramme (`bands` de `ColumnChart`) | `pages/journal/[id]/stats.vue` |
| Export PDF = impression du navigateur : classes `print:` (masquage, `break-inside-avoid`, graphiques sans défilement), thème clair forcé sur `beforeprint` / `afterprint`, titre du document = nom de fichier proposé | `app.vue`, `pages/journal/[id]/stats.vue`, `assets/css/main.css` |

## 9. PWA

Configuration dans `nuxt.config.ts` (`pwa`) :

- `registerType: 'prompt'` : une nouvelle version n'est appliquée qu'après accord de l'utilisateur (`PwaPrompts.vue`), pour ne pas perdre une saisie ; vérification toutes les heures (`periodicSyncForUpdates: 3600`) et, dans `PwaPrompts.vue`, `registration.update()` sur `visibilitychange` (visible) et `online` (au plus une fois par minute) : sur mobile, l'app installée est reprise sans rechargement et le `setInterval` du module est gelé en arrière-plan. Si un service worker est déjà en attente (`registration.waiting`, mise à jour reportée), le bandeau est réaffiché.
- Workbox précache `js, css, html, png, svg, ico, woff2` ; `navigateFallback: '/'`. Les appels Supabase ne sont **pas** mis en cache (gérés par l'application via IndexedDB).
- Bandeau d'installation maison (`installPrompt: true`).
- **Icônes** : embarquées dans le bundle (`icon.clientBundle`, `provider: 'none'`) pour fonctionner hors ligne. Le scan ne détecte que les icônes écrites dans les composants `.vue` : une icône référencée uniquement dans un fichier `.ts` (ex. `WAKE_TYPES`, `APPROACH_KINDS`) doit être ajoutée dans `icon.clientBundle.icons`.
- Icônes de l'application : modifier `public/icon.svg` puis `npm run icons`.

## 10. Environnement et déploiement

### Variables d'environnement

| Variable | Rôle |
|---|---|
| `NUXT_PUBLIC_SUPABASE_URL` | URL du projet Supabase |
| `NUXT_PUBLIC_SUPABASE_KEY` | Clé `anon` publique |

### Commandes

| Commande | Rôle |
|---|---|
| `npm run dev` | serveur de développement |
| `npm run generate` (= `build`) | génération statique dans `.output/public` |
| `npm run preview` | sert le build statique |
| `npm run typecheck` | vérification TypeScript (`vue-tsc`) |
| `npm run icons` | régénère les icônes PWA |

### Vercel

`vercel.json` : `npm ci` + `npm run generate`, sortie `.output/public`, réécriture de toutes les routes vers `index.html` (SPA), `sw.js` jamais mis en cache, `/_nuxt/*` en cache immuable. Déploiement automatique à chaque push sur `main`.

### Supabase

- Appliquer **toutes** les migrations de `supabase/migrations/` dans l'ordre (SQL Editor ou `supabase db push`).
- Authentication → URL Configuration : *Site URL* = URL Vercel ; *Redirect URLs* = `<url>/**` et `http://localhost:3000/**` (confirmation d'email, réinitialisation de mot de passe).

### Ordre de mise en production d'une évolution de schéma

1. Écrire une nouvelle migration `supabase/migrations/<horodatage>_<nom>.sql` (ne jamais modifier une migration déjà appliquée).
2. L'appliquer sur Supabase.
3. Pousser le code sur `main` (déploiement Vercel).

## 11. Recette : ajouter un champ à un réveil

Exemple suivi pour `wake_type` :

1. **Migration** : `alter table public.wakeups add column …` (nullable ou avec valeur par défaut).
2. **Type** : `Wakeup` dans `utils/db.ts` (champ optionnel si les lignes locales existantes ne l'ont pas).
3. **Synchro** : ajouter le champ à `WAKEUP_FIELDS` et, si besoin, une valeur par défaut au pull dans `pullRows`.
4. **Écriture** : valeur initiale dans `addWakeup`, type du `patch` de `updateWakeup`.
5. **Interface** : formulaire `reveil/[wid].vue` (chargement, état, `save`), affichage `WakeupCard.vue`, statistiques.
6. **Icônes** déclarées hors `.vue` → `icon.clientBundle.icons`.
7. `npm run typecheck`.

## 12. Conventions

- Code, commentaires, messages et documentation en **français**.
- Erreurs Supabase traduites pour l'utilisateur via `errorMessage()` (`utils/errors.ts`).
- Toute écriture locale passe par `useJournalActions` (qui marque `_dirty`, `_lmod` et planifie la synchro).
- Les droits sont **toujours** appliqués côté base ; les contrôles côté client ne servent qu'à l'affichage.
