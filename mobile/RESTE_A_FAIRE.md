# Migration Flutter : reste à faire

État au 28/10/2026, branche `feature/flutter`. Étapes 1 à 5 écrites (voir `README.md`) :
`flutter analyze` sans problème, `flutter test` OK (17 tests). L'application fonctionne sur l'émulateur
`Pixel_Tablet` (Android 15, API 35) ; recette détaillée (sections 2 et 3) pas encore faite.
Rien n'est commité : tout le dossier `mobile/` est encore non suivi par git.

## 1. Environnement

- [x] Installer Android Studio (SDK Android 36 + émulateur `Pixel_Tablet`).
- [x] `flutter doctor` sans erreur sur la partie Android (seul Visual Studio est signalé, inutile pour Android).
- [x] `C:\Users\huet\develop\flutter\bin` dans le `PATH`.
- [x] `env.json` créé avec l'URL et la clé Supabase.
- [ ] Ajouter un émulateur au format téléphone (seul `Pixel_Tablet` existe) ou brancher un vrai téléphone.
- [ ] Choisir l'identifiant définitif de l'application (aujourd'hui `fr.pascesoir.pas_ce_soir`, généré par `flutter create --org fr.pascesoir`) : il ne peut plus changer après publication sur le Play Store.
- [ ] Commiter `mobile/` (y compris `android/`).

## 2. Recette des étapes 1 à 4 sur un appareil

`flutter run --dart-define-from-file=env.json`, avec un compte existant de la PWA :

- [ ] Connexion, déconnexion (alerte si modifications non envoyées), mot de passe oublié.
- [ ] Les journaux, réveils, options et démarches de la PWA apparaissent (première synchro).
- [ ] Création d'un réveil (gros bouton, vibration, « Compléter » / « Annuler ») → visible dans la PWA, et inversement.
- [ ] Hors ligne : créer / modifier puis remettre le réseau → l'indicateur passe de « En attente » à « À jour ».
- [ ] Commentaire en texte riche : un commentaire saisi dans la PWA s'affiche correctement dans l'app, et inversement
  (barre d'outils `flutter_quill` : configuration écrite sans pouvoir la voir, vérifier le rendu).
- [ ] Démarches, réglages (options : renommer, ordre, retirer / remettre), partage du lien, membres, profil, admin.
- [ ] Thème, tailles, zones sûres (encoche, barre de navigation Android), clavier qui ne masque pas les champs.

## 3. Étape 5 : statistiques et export PDF (écrite, recette à faire)

Port de `app/pages/journal/[id]/stats.vue` et `app/components/ColumnChart.vue` :
calculs dans `lib/utils/stats.dart` (testés : `test/stats_test.dart`), écran `lib/screens/stats_screen.dart`,
histogramme `lib/widgets/column_chart.dart` (widgets Flutter, pas de `fl_chart`), PDF `lib/services/stats_pdf.dart`
(paquet `pdf`, police Nunito dans `assets/fonts/`, partage par `share_plus` au lieu de `printing`).

Recette sur l'appareil, en comparant avec la page Statistiques de la PWA sur le même journal :

- [ ] Mêmes chiffres que la PWA : chiffres clés, lever / nocturne, semaines / mois, effet des démarches, top raisons, heures.
- [ ] Période : préréglages (7 j, 30 j, 3 mois, 1 an), « Tout », dates « Du » / « Au ».
- [ ] Histogramme : défilement horizontal sur 1 an (positionné sur les semaines récentes), infobulles au tap
  (barres et bandes de la frise), bascule Semaine / Mois, tableau.
- [ ] Bouton PDF : le menu de partage Android s'ouvre ; enregistrer dans Fichiers et ouvrir le PDF.
  Le tableau n'est inclus que s'il est affiché à l'écran (comme l'impression de la PWA).
- [ ] Rendu de l'en-tête de carte « Réveils par semaine » (titre + bascule) sur un téléphone étroit.

## 4. Liens profonds (Android App Links)

Détail dans `README.md`, section « Liens profonds ».

- [ ] Ajouter l'`intent-filter` dans `android/app/src/main/AndroidManifest.xml` (le fichier existe maintenant).
- [ ] `cd android && ./gradlew signingReport` → empreinte SHA-256 (debug, puis certificat de publication).
- [ ] Créer `public/.well-known/assetlinks.json` dans le projet Nuxt et déployer sur Vercel.
- [ ] Vérifier : `adb shell pm get-app-links fr.pascesoir.pas_ce_soir` → `verified`.
- [ ] Tester : lien d'invitation à un journal, invitation admin, confirmation d'email, mot de passe oublié
  (flux PKCE : le lien doit être ouvert sur l'appareil où la demande a été faite).

## 5. Publication

- [ ] Icône de l'application (`flutter_launcher_icons` à partir de `assets/icon.svg` / `public/pwa-512x512.png`) et écran de démarrage.
- [ ] Nom affiché « Pas ce soir » (`android:label` dans `AndroidManifest.xml`).
- [ ] Clé de signature de publication (`key.properties`, déjà ignorés par `.gitignore`), build `flutter build appbundle`.
- [ ] Compte Google Play (25 $), fiche, politique de confidentialité ; ou diffusion directe de l'APK aux parents.
- [ ] Mettre à jour l'empreinte de publication dans `assetlinks.json`.

## 6. Après la bascule

- [ ] Remplacer la PWA par une page statique minimale (« Installez l'application ») + `assetlinks.json`
  (indispensable pour les liens profonds et les liens d'email).
- [ ] Supprimer le projet Nuxt de la racine, mettre à jour `README.md` et `docs/`.

## Améliorations possibles (non bloquantes)

- [ ] Montées de version majeures disponibles : `go_router` 18, `share_plus` 13.
  Avertissement au build Android : `share_plus` applique le Kotlin Gradle Plugin, que les futures versions
  de Flutter refuseront (« Built-in Kotlin ») ; vérifier si `share_plus` 13 règle le problème.
- [ ] Tests unitaires de la synchronisation (`lib/services/sync_service.dart`) et de `lib/utils/night.dart`.
- [ ] Police Nunito (celle de la PWA) pour toute l'application : les fichiers sont déjà dans `assets/fonts/`
  (400 et 700, sous-ensemble latin, licence SIL OFL), seul le PDF les utilise pour l'instant.
- [ ] Spécificités natives : notifications, widget d'écran d'accueil avec le bouton RÉVEIL.
