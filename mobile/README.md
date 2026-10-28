# Pas ce soir — application Android (Flutter)

Portage Flutter de la PWA Nuxt (racine du dépôt). Le backend Supabase est le même : aucune migration à faire.

## Prérequis

1. [Flutter](https://docs.flutter.dev/get-started/install/windows/mobile) (canal stable) dans le `PATH`
2. Android Studio : SDK Android et un émulateur (ou un téléphone en mode développeur)
3. `flutter doctor` sans erreur sur la partie Android

## Première installation

Le dossier `android/` n'est pas encore dans le dépôt : il est généré par Flutter.

```bash
cd mobile
flutter create --platforms=android,web --org fr.pascesoir --project-name pas_ce_soir .
flutter pub get
cp env.example.json env.json   # puis renseigner l'URL et la clé anon Supabase
```

`flutter create` ne remplace pas les fichiers de `lib/` existants. Supprimer le `test/widget_test.dart` généré : il teste l'application exemple.

Le dossier `web/` contient `sqlite3.wasm` et `sqflite_sw.js`, utilisés par `sqflite_common_ffi_web`. Il faut les regénérer avec `dart run sqflite_common_ffi_web:setup --force` après une mise à jour de ce package.

## Lancer

```bash
flutter run --dart-define-from-file=env.json
flutter run -d chrome --dart-define-from-file=env.json   # version web (SQLite en wasm)
flutter test      # tests unitaires (conversion des commentaires HTML <-> Delta)
```

## Avancement de la migration

| Étape | Contenu | État |
|---|---|---|
| 1 | Socle : thème sombre, `go_router`, authentification Supabase (connexion, inscription sur invitation, mot de passe oublié) | ✅ |
| 2 | Base locale (SQLite) et synchronisation (port de `useSync`), liste des journaux | ✅ |
| 3 | Accueil, journal (bouton RÉVEIL, nuit en cours, historique), formulaire de réveil (commentaire en texte riche) | ✅ |
| 4 | Démarches, réglages (options, partage, membres), profil, administration, invitations, liens profonds (voir plus bas) | ✅ |
| 5 | Statistiques, graphiques (widgets maison, sans paquet), export PDF (`pdf` + partage `share_plus`, police Nunito embarquée) | ✅ |

## Structure

```
lib/
├── main.dart                 # initialisation Supabase, services, MaterialApp
├── config.dart               # SUPABASE_URL / SUPABASE_KEY (--dart-define-from-file)
├── theme.dart                # couleurs reprises de la PWA, thème Material 3 sombre
├── router.dart               # routes (mêmes chemins que la PWA) + redirections (équivalent de auth.global.ts)
├── data/
│   ├── models.dart           # Journal, JournalOption, Wakeup, Approach, Member + listes fixes (WakeType, ApproachKind, DayPeriod)
│   ├── local_db.dart         # base SQLite par utilisateur + requêtes réactives (équivalent de Dexie / liveQuery)
│   └── journal_repository.dart # écritures locales + requêtes watch… (équivalent de useJournal)
├── services/
│   ├── auth_service.dart     # équivalent de useAuth
│   ├── sync_service.dart     # synchronisation SQLite <-> Supabase (équivalent de useSync)
│   └── stats_pdf.dart        # rapport PDF des statistiques (thème clair), partagé via le menu Android
├── screens/                  # écrans
├── widgets/                  # composants réutilisables (SyncStatus…)
└── utils/                    # errors (messages), night (notion de nuit, formats de date), approach (état des démarches), stats (calculs des statistiques),
                              # rich_text (commentaires : HTML TipTap <-> Delta Quill)
```

## Données locales

Une base SQLite par utilisateur (`pascesoir-<userId>.db`), via `sqflite`. Chaque ligne est stockée en JSON dans
la colonne `data`, avec les mêmes champs que Supabase plus `_dirty` / `_lmod` ; seules les colonnes utiles aux
requêtes en sont extraites (`journal_id`, `woke_at` en microsecondes, `_dirty`, `deleted`). Ajouter un champ non
filtré ne demande donc pas de migration locale.

`AppDb.watch(tables, requête)` relance la requête après chaque écriture touchant ces tables (y compris par la
synchro) : créer le flux une seule fois par écran (`initState` / `late final`), pas dans `build`.

La synchronisation suit exactement l'algorithme de la PWA (voir `docs/technique.md` § 7). Déclencheurs :
démarrage, retour du réseau (`connectivity_plus`), retour au premier plan, toutes les 30 s au premier plan, et
après chaque écriture locale.

## Liens profonds (Android App Links)

Les liens envoyés par l'application restent des URL du site (`WEB_BASE_URL`, par défaut
`https://pas-ce-soir.vercel.app`) : invitation à un journal (`/rejoindre/<jeton>`), invitation admin
(`/inscription/<jeton>`), confirmation d'email (`/connexion`) et mot de passe oublié (`/nouveau-mot-de-passe`).
Une fois les App Links configurés, Android ouvre ces liens directement dans l'application si elle est
installée (sinon dans le navigateur). `go_router` affiche l'écran correspondant et `supabase_flutter`
récupère la session présente dans les liens de confirmation / réinitialisation.

### 1. Déclarer les liens dans l'application

Dans `android/app/src/main/AndroidManifest.xml`, dans l'`<activity android:name=".MainActivity" …>` :

```xml
<intent-filter android:autoVerify="true">
    <action android:name="android.intent.action.VIEW" />
    <category android:name="android.intent.category.DEFAULT" />
    <category android:name="android.intent.category.BROWSABLE" />
    <data android:scheme="https" android:host="pas-ce-soir.vercel.app" />
    <data android:pathPrefix="/rejoindre/" />
    <data android:pathPrefix="/inscription/" />
    <data android:path="/connexion" />
    <data android:path="/nouveau-mot-de-passe" />
</intent-filter>
```

### 2. Prouver que le site appartient à l'application

Récupérer l'empreinte SHA-256 du certificat de signature (debug pour les essais, puis celui de publication) :

```bash
cd android && ./gradlew signingReport
```

Créer `public/.well-known/assetlinks.json` dans le projet **Nuxt** (servi tel quel par Vercel, avant la
réécriture vers `index.html`) :

```json
[{
  "relation": ["delegate_permission/common.handle_all_urls"],
  "target": {
    "namespace": "android_app",
    "package_name": "fr.pascesoir.pas_ce_soir",
    "sha256_cert_fingerprints": ["AA:BB:…"]
  }
}]
```

Vérifier ensuite sur l'appareil : `adb shell pm get-app-links fr.pascesoir.pas_ce_soir` (état `verified`).

### Limites

- La confirmation d'email et la réinitialisation utilisent le flux PKCE : le lien doit être ouvert sur
  l'appareil (et dans l'application) où la demande a été faite.
- Sans l'application installée, les liens ouvrent le site : il doit rester en ligne (au minimum une page
  « Installez l'application » et le fichier `assetlinks.json`).
