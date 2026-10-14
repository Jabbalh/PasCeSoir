# Pas ce soir 🌙

Journal des réveils nocturnes d'un enfant — PWA mobile, utilisable hors connexion, partagée entre parents.

**Stack** : Nuxt 4 (SPA) · Nuxt UI 4 · Tailwind CSS 4 · Supabase (auth + Postgres) · Dexie (IndexedDB) · Vite PWA · Vercel

## Fonctionnalités

- **Gros bouton « RÉVEIL »** : un appui = un réveil horodaté (vibration + toast « Compléter / Annuler »)
- **Compléter un réveil** : date/heure, raisons, actions (suggestions + saisie libre), commentaire en texte riche (gras, italique, listes…), auteur enregistré automatiquement
- **Nuit en cours + historique** groupé par nuit (une nuit = 14h → 14h le lendemain)
- **Statistiques** sur une période (préréglages ou date à date) : réveils par semaine / par mois, top 10 des raisons, répartition horaire
- **Partage** : lien d'invitation `/rejoindre/<jeton>` → la personne crée un compte et rejoint le journal
- **Hors connexion** : toutes les données sont dans IndexedDB ; les modifications sont envoyées à Supabase dès que le réseau revient

## Installation

```bash
npm install
cp .env.example .env   # puis renseigner l'URL et la clé anon Supabase
npm run dev
```

### Supabase

1. Créer un projet sur [supabase.com](https://supabase.com)
2. **SQL Editor** → exécuter `supabase/migrations/20261014000000_init.sql`
3. **Authentication → URL Configuration** :
   - *Site URL* : l'URL Vercel (ex. `https://pas-ce-soir.vercel.app`)
   - *Redirect URLs* : `https://pas-ce-soir.vercel.app/**` et `http://localhost:3000/**`
4. Récupérer `Project URL` et la clé `anon public` (Settings → API)

### Vercel

1. Importer le dépôt dans Vercel (le `vercel.json` configure le build statique `nuxt generate`)
2. Ajouter les variables d'environnement `NUXT_PUBLIC_SUPABASE_URL` et `NUXT_PUBLIC_SUPABASE_KEY`
3. Déployer

## Synchronisation

- Chaque écriture est d'abord locale (`_dirty = 1`), puis poussée par `upsert` (identifiants UUID générés côté client).
- Le serveur horodate `updated_at` ; chaque journal a un curseur de synchro, avec 60 s de recouvrement.
- Suppression = *soft delete* (`deleted_at`) pour propager l'effacement aux autres appareils.
- Conflit : la dernière écriture envoyée l'emporte ; une modification locale non envoyée n'est jamais écrasée.
- Déclencheurs : démarrage, retour du réseau, retour au premier plan, toutes les 30 s, et après chaque modification.
- Une base IndexedDB par utilisateur (`pascesoir-<userId>`).

## Icônes PWA

Modifier `public/icon.svg` puis `npm run icons`.
