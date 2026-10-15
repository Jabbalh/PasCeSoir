# Documentation fonctionnelle

## 1. Objectif

**Pas ce soir** permet aux parents de noter, en un geste et en pleine nuit, chaque réveil de leur enfant, puis de compléter le détail plus tard (raison, ce qui a été fait, commentaire) et d'en tirer des statistiques.

Points clés :

- **Rapide** : un seul appui sur le gros bouton « RÉVEIL » enregistre un réveil horodaté.
- **Partagé** : les deux parents (ou plus) alimentent le même journal, chacun avec son compte.
- **Hors connexion** : tout fonctionne sans réseau ; les données se synchronisent dès que la connexion revient.
- **Installable** : l'application s'installe sur l'écran d'accueil du téléphone (PWA).

## 2. Concepts

| Concept | Définition |
|---|---|
| **Journal** | Carnet des nuits d'un enfant (nom du journal + prénom de l'enfant). Un utilisateur peut avoir plusieurs journaux. |
| **Membre** | Utilisateur ayant accès à un journal. Rôle **propriétaire** (le créateur) ou **membre** (a rejoint via un lien). |
| **Réveil** | Évènement daté dans un journal : date/heure, type, raisons, actions, commentaire, auteur. |
| **Type de réveil** | **Lever** (réveil du matin) ou **Réveil nocturne**. Vide par défaut. |
| **Raison** | Cause du réveil (ex. « Cauchemar », « Faim »). Liste propre à chaque journal. |
| **Action** | Ce qui a été fait (ex. « Câlin », « Biberon »). Liste propre à chaque journal. |
| **Démarche** | Ce qui est mis en place pour améliorer les nuits, de date à date (sans date de fin = **en cours**) : type (**Rituel**, **Médication**, **Soin** (psychomotricien, ergothérapeute, orthophoniste…), **Alimentation**, **Environnement**, **Autre**), nom, moment(s) de la journée, commentaire. |
| **Nuit** | Période de **14h à 14h le lendemain**. Un réveil à 3h du matin le mardi appartient à la « nuit du lundi au mardi ». |
| **Administrateur** | Utilisateur pouvant inviter de nouvelles personnes à utiliser l'application. |

## 3. Rôles et droits

| Action | Membre | Propriétaire | Administrateur |
|---|:-:|:-:|:-:|
| Voir le journal, ses réveils et statistiques | ✅ | ✅ | — |
| Ajouter / modifier / supprimer un réveil | ✅ | ✅ | — |
| Ajouter / modifier / supprimer une démarche | ✅ | ✅ | — |
| Gérer les listes de raisons et d'actions | ✅ | ✅ | — |
| Modifier le nom du journal / le prénom | ✅ | ✅ | — |
| Partager / copier le lien de partage existant | ✅ | ✅ | — |
| Créer, renouveler ou désactiver le lien de partage | ❌ | ✅ | — |
| Retirer un membre | ❌ | ✅ | — |
| Quitter le journal | ✅ | ❌ | — |
| Supprimer le journal (pour tous) | ❌ | ✅ | — |
| Créer / révoquer des invitations à l'application | — | — | ✅ |

> Les administrateurs sont désignés directement dans la base Supabase (voir [base de données](base-de-donnees.md#administrateurs)).

## 4. Accès à l'application

### 4.1 Inscription (sur invitation uniquement)

Il n'est pas possible de créer un compte librement. Trois voies existent :

1. **Lien de partage d'un journal** (`/rejoindre/<jeton>`) : la personne crée son compte et **rejoint automatiquement** le journal.
2. **Invitation à l'application** (`/inscription/<jeton>`) créée par un administrateur : à **usage unique**, valable 24 h, 7 jours ou 30 jours ; la personne crée son compte puis son propre journal.
3. **Liste blanche d'emails** gérée dans Supabase (`signup_allowlist`).

Un lien expiré, révoqué ou déjà utilisé affiche « Invitation invalide ». Selon la configuration Supabase, un email de confirmation peut être demandé avant la première connexion.

### 4.2 Connexion et mot de passe

- Connexion par email + mot de passe (`/connexion`).
- « Mot de passe oublié » : un email contient un lien vers `/nouveau-mot-de-passe`.
- Hors connexion, le dernier utilisateur connecté reste connecté et l'application reste utilisable.

### 4.3 Déconnexion

Si des modifications ne sont pas encore synchronisées, une confirmation est demandée (elles seraient perdues).

## 5. Écrans

### 5.1 Mes journaux (`/`)

- Liste des journaux avec leur nombre de réveils.
- **Nouveau journal** : prénom de l'enfant (obligatoire) et nom du journal (par défaut « Les nuits de <prénom> »).
- Au lancement, l'application ouvre directement le **dernier journal consulté** (ou l'unique journal).

### 5.2 Journal — Réveils (`/journal/<id>`)

- **Gros bouton « RÉVEIL »** : enregistre un réveil à l'heure actuelle (vibration + message « Réveil enregistré à HH:MM » avec les actions **Compléter** et **Annuler**). Un délai de 2 s évite les doubles appuis.
- **Nuit en cours** : réveils de la nuit actuelle, dans l'ordre chronologique.
- **Historique** : nuits précédentes groupées par nuit (7 nuits affichées, puis « voir plus »).
- Chaque réveil affiche l'heure, le type (si renseigné), l'auteur, les raisons (orange) et actions (vert), un extrait du commentaire. Un réveil sans raison, action ni commentaire est marqué **« À compléter »**.
- Une icône nuage signale un réveil pas encore envoyé au serveur.
- **Démarches en cours** : sous le bouton, rappel compact des démarches en place aujourd'hui (avec leurs moments), qui ouvre l'onglet Démarches.

### 5.3 Détail d'un réveil (`/journal/<id>/reveil/<id>` ou `/reveil/nouveau`)

| Champ | Règle |
|---|---|
| Date et heure | Obligatoire. Pré-remplie à l'heure actuelle pour un nouveau réveil. |
| Type de réveil | Facultatif : **Lever** ou **Réveil nocturne**. Recliquer sur le choix actif le désélectionne. |
| Raison(s) | Choix multiple dans la liste du journal. « Autre raison… » ajoute une nouvelle raison à la liste pour la réutiliser. |
| Ce qui a été fait | Idem pour les actions. |
| Commentaire | Texte riche (gras, italique, listes…). |
| Auteur | Automatique : l'utilisateur qui a créé le réveil (« Compte supprimé » si son compte n'existe plus). |

Suppression : avec confirmation, puis possibilité d'**Annuler** pendant quelques secondes.

### 5.4 Démarches (`/journal/<id>/demarches`)

Ce qui est mis en place pour améliorer les nuits (rituel du coucher, traitement, changement d'alimentation ou de chambre…), afin d'en mesurer l'effet sur les réveils.

- Liste groupée en **En cours**, **À venir** (début dans le futur) et **Terminées** (date de fin passée).
- Chaque démarche affiche son type (icône et couleur), son nom, ses dates (« Depuis le… », « Du… au… », « À partir du… »), ses moments et un extrait du commentaire.

Détail (`/journal/<id>/demarches/<id>` ou `/demarches/nouveau`) :

| Champ | Règle |
|---|---|
| Type | Obligatoire : **Rituel**, **Médication**, **Soin** (suivi par un professionnel : psychomotricien, ergothérapeute…), **Alimentation**, **Environnement** ou **Autre** (liste fixe). |
| Nom | Obligatoire (ex. « Bain avant le coucher », « Mélatonine 1 mg »). |
| Du | Obligatoire, aujourd'hui par défaut. |
| Au | Facultatif, date **incluse**. Vide = **toujours en cours**. Boutons « Terminer aujourd'hui » / « Toujours en cours ». Doit suivre la date de début. |
| Moment(s) de la journée | Facultatif, choix multiple : **Matin**, **Midi**, **Après-midi**, **Soir / coucher**, **Nuit**. |
| Commentaire | Texte riche (dosage, déroulé…). |
| Auteur | Automatique. |

Une démarche est rattachée aux **nuits** dont la date du soir est comprise entre ses dates de début et de fin. Suppression : avec confirmation, puis **Annuler** possible quelques secondes.

### 5.5 Statistiques (`/journal/<id>/stats`)

Période choisie par préréglage (7 j, 30 j, 3 mois, 1 an, Tout) ou de date à date (« nuit du … »).

- **Chiffres clés** : nombre de réveils, moyenne par nuit, nuits sans réveil.
- **Lever ou réveil nocturne** : barre de répartition + nombre et pourcentage par type (Lever, Réveil nocturne, Non renseigné).
- **Réveils par semaine / par mois** : histogramme **empilé par type** (orange = Lever, couleur principale = Réveil nocturne, gris = Non renseigné), infobulle détaillée, et vue tableau avec une colonne par type.
- **Frise des démarches** : sous l'histogramme, une ligne colorée par démarche (couleur du type) sur les semaines / mois où elle était en place.
- **Effet des démarches** : pour chaque démarche de la période, réveils nocturnes par nuit (levers exclus) **pendant** la démarche, comparés aux **30 nuits précédant** son début, avec l'évolution en %. La nuit en cours est exclue ; le calcul porte sur tout l'historique.
- **Top 10 des raisons** : nombre et pourcentage (sur le nombre de réveils ; un réveil peut avoir plusieurs raisons).
- **À quelle heure ?** : répartition des réveils par heure, de 18h à 11h.

Les semaines commencent le lundi ; un réveil est compté dans la semaine / le mois de **sa nuit**.

**Export PDF** : le bouton « PDF » ouvre l'impression du téléphone / navigateur ; choisir « Enregistrer au format PDF ». Le document reprend la période choisie (en-tête : journal, prénom, nuits couvertes, date de génération), en thème clair, sans les boutons ni la navigation. Le tableau n'apparaît que s'il est affiché à l'écran. Fonctionne hors connexion.

### 5.6 Réglages du journal (`/journal/<id>/reglages`)

- **Informations** : nom du journal et prénom de l'enfant.
- **Raisons et actions** : ajouter, renommer, réordonner (monter / descendre), retirer de la liste.
  - Un nouveau journal démarre avec des listes **vides**.
  - Renommer une option met à jour **tout l'historique**.
  - Retirer une option l'**archive** : elle n'est plus proposée mais reste affichée sur les anciens réveils ; elle peut être restaurée. Ajouter une option portant le nom d'une option archivée la restaure.
  - Le nombre de réveils utilisant chaque option est affiché.
- **Partager le journal** (connexion requise) : tout membre peut partager / copier le lien existant ; seul le propriétaire peut le créer, en générer un **nouveau** (l'ancien cesse de fonctionner) ou le **désactiver**.
- **Membres** : liste avec le rôle (Créateur / Membre) ; le propriétaire peut retirer un membre.
- **Zone sensible** : le propriétaire peut **supprimer le journal** pour tous les membres ; un membre peut **quitter le journal**.

### 5.7 Rejoindre un journal (`/rejoindre/<jeton>`)

Affiche le nom du journal et le prénom de l'enfant, puis bouton **Rejoindre**. Connexion internet requise. Sans compte, la personne est redirigée vers la création de compte.

### 5.8 Mon profil (`/profil`)

- Modifier le **nom affiché** (visible par les autres membres comme auteur des réveils).
- **Supprimer mon compte** : un aperçu liste les conséquences avant confirmation :
  - journaux dont l'utilisateur est **propriétaire** → supprimés **pour tous** (case à cocher obligatoire si d'autres membres y ont accès) ;
  - journaux dont il est **membre** → il les quitte ; les réveils qu'il y a saisis sont conservés, sans auteur ;
  - modifications non synchronisées → perdues ;
  - données locales du téléphone → effacées.

### 5.9 Administration (`/admin`, administrateurs uniquement)

- Créer une invitation : « Pour qui ? » (note libre) et validité (24 h, 7 j, 30 j) ; le lien est aussitôt proposé au partage.
- Liste des invitations avec leur statut : **Active jusqu'au…**, **Utilisée par …**, **Révoquée**, **Expirée**.
- Partager à nouveau ou **révoquer** une invitation active.

## 6. Hors connexion et synchronisation

- Toutes les saisies sont enregistrées **sur le téléphone** d'abord, puis envoyées au serveur.
- Indicateur dans l'en-tête : **À jour**, **En attente** (nombre de modifications), **Synchro…**, **Hors ligne**, **Erreur**. Un appui force une synchronisation.
- Synchronisation au démarrage, au retour du réseau, au retour dans l'application, toutes les 30 s et après chaque modification.
- En cas de modification simultanée du même réveil sur deux appareils, **la dernière modification envoyée l'emporte**.
- Nécessitent une connexion : création de compte, rejoindre un journal, gestion du partage et des membres, profil, administration.

## 7. Application installable (PWA)

- Bandeau **« Installer Pas ce soir »** (Android / Chrome). Sur iPhone, pas de bandeau : Safari → Partager → « Sur l'écran d'accueil ».
- Message **« Prêt pour le hors connexion »** à la première installation du cache.
- **Nouvelle version disponible** : l'utilisateur choisit « Mettre à jour » ou « Plus tard » (pour ne pas perdre une saisie en cours). Vérification au lancement, à chaque retour dans l'application, au retour du réseau et toutes les heures. Une version reportée avec « Plus tard » est reproposée au retour suivant dans l'application.
