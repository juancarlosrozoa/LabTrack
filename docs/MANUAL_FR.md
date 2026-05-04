# LabTrack — Manuel Utilisateur

> Version 1.0 · Mai 2026

---

## Table des matières

1. [Qu'est-ce que LabTrack ?](#1-quest-ce-que-labtrack)
2. [Premiers pas](#2-premiers-pas)
3. [Tableau de bord](#3-tableau-de-bord)
4. [Inventaire](#4-inventaire)
5. [Produits](#5-produits)
6. [Mouvements](#6-mouvements)
7. [Comptage d'inventaire](#7-comptage-dinventaire)
8. [Rapports](#8-rapports)
9. [Paramètres](#9-paramètres)
10. [Lecture de codes-barres](#10-lecture-de-codes-barres)
11. [Synchronisation et utilisation hors ligne](#11-synchronisation-et-utilisation-hors-ligne)
12. [Deux modes de gestion de laboratoire](#12-deux-modes-de-gestion-de-laboratoire)

---

## 1. Qu'est-ce que LabTrack ?

LabTrack est une application mobile de gestion des stocks de laboratoire. Elle permet de :

- Enregistrer des produits avec ou sans numéro de lot
- Suivre les entrées, sorties, retours et ajustements de stock
- Effectuer des comptages physiques périodiques (hebdomadaires, mensuels, etc.)
- Consulter des rapports de consommation, de tendance historique et d'analyse des écarts
- Travailler hors ligne — les données se synchronisent automatiquement dès qu'une connexion est disponible
- Gérer plusieurs laboratoires depuis un seul compte

---

## 2. Premiers pas

### 2.1 Connexion

À la première ouverture de l'application, l'écran **Login** s'affiche.

- Saisissez votre adresse e-mail et votre mot de passe.
- Si vous n'avez pas encore de compte, appuyez sur le lien **Sign up** pour vous inscrire.
- Une fois authentifié, l'application vous dirige vers le sélecteur de laboratoire.

### 2.2 Sélectionner ou créer un laboratoire

Sur l'écran **Lab Picker** :

- Si vous appartenez déjà à un laboratoire, il apparaît dans la liste — appuyez dessus pour y accéder.
- Pour en créer un nouveau, appuyez sur **Create new lab**, saisissez un nom et confirmez.
- Si vous avez été invité à un laboratoire existant, un administrateur doit vous ajouter depuis les Paramètres.

> Vous pouvez changer de laboratoire à tout moment depuis **Paramètres → Changer de laboratoire**.

---

## 3. Tableau de bord

Le tableau de bord est l'écran d'accueil. Il affiche un résumé de l'état actuel de l'inventaire.

### Indicateurs clés (KPI)

| Indicateur | Description |
|------------|-------------|
| **Products** | Nombre total de produits actifs enregistrés |
| **Alerts** | Nombre de produits en stock critique ou épuisé |
| **Reorder** | Produits qui ont atteint leur point de réapprovisionnement |

### Sections d'alerte

- **Critical Stock** — produits en dessous du niveau minimum configuré. Appuyez sur une carte pour accéder au détail du produit.
- **Reorder Needed** — produits passés en dessous du point de réapprovisionnement, mais pas encore au niveau critique.
- **Expiring Soon (≤ 30 jours)** — lots dont la date de péremption est proche. Affiche le lot spécifique et sa date.
- **All clear** — s'affiche lorsqu'aucune alerte n'est active.

### Actions rapides

- **Paramètres** (icône engrenage, coin supérieur droit) → ouvre l'écran Paramètres.
- **Déconnexion** (icône de sortie) → ferme la session.

---

## 4. Inventaire

L'onglet **Inventory** affiche tous les produits actifs avec leur quantité de stock actuelle.

### Recherche et filtrage

- **Barre de recherche** — filtre par nom de produit ou code-barres. Un bouton de suppression (×) apparaît quand du texte est saisi.
- **Scanner un code-barres** (icône scanner, barre d'application) — ouvre la caméra pour rechercher par code.
- **Puces de statut** — filtrent la liste selon le statut du stock :
  - `All` — tous les produits
  - `OK` — stock dans les niveaux normaux
  - `Reorder` — en dessous du point de réapprovisionnement
  - `Critical` — en dessous du stock minimum
  - `Out` — stock à zéro

### Carte produit

Chaque carte affiche :
- Nom du produit et unité de mesure
- Code-barres (si assigné)
- Indication si le produit utilise des lots ou une quantité directe
- **Badge de stock** avec indicateur de couleur :
  - Vert → OK
  - Jaune/Orange → réapprovisionnement
  - Rouge → critique ou épuisé

Appuyez sur une carte pour voir le **détail du produit** (lots, quantité par lot, dates de péremption).

### Ajouter un produit

Appuyez sur le bouton **+ Add product** (coin inférieur droit) pour ouvrir le formulaire de création de produit.

---

## 5. Produits

L'écran **Products** (accessible depuis Inventaire → Add product, ou depuis le catalogue général) liste tous les produits enregistrés.

### Ajouter un nouveau produit

Appuyez sur l'icône **+** dans la barre d'application. Le formulaire demande :

| Champ | Obligatoire | Description |
|-------|-------------|-------------|
| Nom | Oui | Nom descriptif du produit |
| Unité | Oui | Unité de mesure (mL, g, L, unités, etc.) |
| Code-barres | Non | Peut être scanné avec la caméra |
| Catégorie | Non | Sélectionner parmi les catégories configurées |
| Fournisseur | Non | Sélectionner dans le catalogue des fournisseurs |
| Emplacement | Non | Lieu de stockage |
| Condition de stockage | Non | Température, humidité, sensibilité à la lumière |
| Stock minimum | Non | Niveau critique — déclenche une alerte si atteint |
| Point de réapprovisionnement | Non | Niveau préventif — déclenche une alerte préventive |
| **Tracks lots** | Non | Activer si ce produit est géré par numéro de lot et date de péremption |

> **Tracks lots ?** — Lorsque cette option est activée, le stock est calculé en additionnant les quantités de tous les lots actifs. Lorsqu'elle est désactivée, le stock est une valeur directe mise à jour par les mouvements.

### Modifier un produit

Depuis la liste des produits, appuyez sur le produit puis sur l'icône de modification, ou appuyez directement sur la ligne dans l'écran Inventaire.

---

## 6. Mouvements

L'onglet **Movements** enregistre toutes les transactions qui affectent le stock. Chaque mouvement est conservé dans l'historique.

### Types de mouvement

| Type | Quand l'utiliser |
|------|-----------------|
| **Entry** | Réception de nouvelles marchandises ou réapprovisionnement |
| **Exit** | Consommation ou distribution d'un produit |
| **Return** | Retour d'un produit à l'inventaire (ex. : surplus d'une expérience) |

### Enregistrer un mouvement

1. Appuyez sur le bouton correspondant sur l'écran Mouvements :
   - **Entry** (bouton principal vert)
   - **Exit** (bouton principal, rangée supérieure)
   - **Return** (bouton secondaire, rangée inférieure)
2. Sélectionnez le produit (recherche par nom ou scan).
3. Si le produit utilise des lots, sélectionnez un lot ou créez-en un nouveau (pour les entrées).
4. Saisissez la quantité.
5. Ajoutez optionnellement un motif, une zone ou un projet.
6. Appuyez sur **Save** pour confirmer.

Le stock du produit est mis à jour immédiatement.

### Scan Count (Comptage par scan)

Depuis l'écran Mouvements, appuyez sur le bouton **Scan Count** pour lancer un comptage individuel article par article :

1. Scannez ou sélectionnez un produit.
2. Saisissez la quantité comptée physiquement.
3. Répétez pour chaque produit.
4. À la fin, appuyez sur **Save count result** (si tout correspond) ou sur **Approve N adjustments** (s'il y a des différences — ceci applique les ajustements à l'inventaire).

La session de comptage est enregistrée dans l'historique.

### Historique des mouvements

La liste principale de l'onglet Mouvements affiche les 50 derniers mouvements du laboratoire, du plus récent au plus ancien, avec le type, le produit, la quantité et la date.

---

## 7. Comptage d'inventaire

L'onglet **Count** (Weekly Count) sert à effectuer un comptage physique complet de l'inventaire.

### Comment ça fonctionne

1. Appuyez sur **Start Count Session**.
2. L'application charge tous les produits actifs avec leurs quantités actuelles selon le système.
3. Pour chaque produit, saisissez la quantité trouvée physiquement.
4. À la fin, l'application compare les quantités attendues et comptées, et affiche les écarts.
5. Appuyez sur **Approve adjustments** pour appliquer les différences à l'inventaire, ou sur **Save without adjusting** pour enregistrer le comptage sans modifier le stock.

### Résultats de la session de comptage

Chaque session enregistre :
- Date et heure du comptage
- Nombre total de produits comptés
- Nombre d'écarts constatés
- Détail par produit : quantité attendue, quantité comptée et différence

Vous pouvez consulter l'historique des comptages depuis **Rapports → History**.

> **Fréquence recommandée :** Pour les laboratoires qui n'enregistrent pas les mouvements individuels, des comptages hebdomadaires ou mensuels sont recommandés pour maintenir l'inventaire à jour.

---

## 8. Rapports

L'onglet **Reports** comporte deux niveaux : le rapport de statut actuel et trois rapports d'analyse historique.

### Rapport de statut (écran principal)

Affiche une photographie de l'inventaire au moment présent :

- **KPI :** total de produits, alertes actives, produits en réapprovisionnement
- **Out of Stock** — produits sans stock
- **Critical Stock** — produits en dessous du niveau minimum
- **Reorder Needed** — produits en dessous du point de réapprovisionnement
- **Expiring Soon** — lots dont la date de péremption est proche
- **Full Inventory** — liste complète avec la quantité et le statut de chaque produit

Actions disponibles :
- **Sync to Google Sheets** (icône tableau) — exporte l'inventaire actuel vers une feuille de calcul Google.
- **Share via email** — génère un rapport textuel et l'ouvre dans le client de messagerie pour le partager.

### Rapports d'analyse (cartes d'accès rapide)

Appuyez sur l'une des trois cartes sous l'en-tête :

---

#### Consumption (Consommation)

Affiche la consommation de chaque produit sur une période donnée, **basée sur les mouvements de sortie enregistrés**.

- Sélectionnez la période avec les puces : **Last 7 days**, **Last 30 days**, **Last 90 days**.
- Les produits sont triés du plus au moins consommé.
- Chaque ligne affiche le total consommé, l'unité et le nombre de mouvements individuels (badge `×N`).
- La barre de progression est proportionnelle au produit le plus consommé.

> Si le laboratoire n'enregistre pas les sorties individuelles, cet écran sera vide avec un guide pour commencer à le faire.

---

#### Trend (Tendance d'inventaire)

Montre l'évolution de l'inventaire physique au fil des derniers comptages, **basé sur les sessions de comptage enregistrées**.

- Le tableau comporte une colonne par session de comptage (max. 4 sessions récentes, de la plus ancienne à la plus récente).
- La colonne **Change** affiche la différence entre le premier et le dernier comptage enregistré pour chaque produit :
  - Rouge avec `−` → consommation (la quantité a diminué)
  - Vert avec `+` → augmentation (la quantité a augmenté)
- Les produits non comptés lors d'une session apparaissent avec `—`.

> Ce rapport est utile aussi bien pour les laboratoires qui suivent les mouvements que pour ceux qui effectuent uniquement des comptages. La colonne « Change » permet d'inférer la consommation entre les périodes.

---

#### History (Historique des comptages)

Liste toutes les sessions de comptage enregistrées, de la plus récente à la plus ancienne.

- Appuyez sur une session pour la développer et voir le détail par produit.
- La vue développée affiche : produit, quantité attendue, quantité comptée et badge d'écart (vert = aucun écart, rouge = manque, orange = surplus).

---

## 9. Paramètres

Accessible depuis l'icône engrenage sur le Tableau de bord (coin supérieur droit).

### Laboratoire

Affiche le nom du laboratoire actif et votre rôle (Admin / Membre).

- **Switch laboratory** — retourne au sélecteur de laboratoire pour changer de laboratoire.

### Catégories

Regroupe les produits par type (ex. : Réactifs, Équipements, Produits de nettoyage).

- Appuyez sur **+ Add category** pour en créer une.
- Appuyez sur l'icône de modification (crayon) pour la renommer.
- Appuyez sur l'icône de suppression (corbeille) pour la supprimer.

> Les catégories supprimées n'affectent pas les produits qui les avaient déjà assignées.

### Emplacements

Définit les lieux de stockage du laboratoire (ex. : Réfrigérateur 1, Armoire A, Entrepôt).

- Mêmes opérations que pour les Catégories.

### Fournisseurs

Catalogue des fournisseurs avec nom, e-mail de contact et numéro de téléphone.

- Appuyez sur **+ Add supplier** pour en créer un.
- Remplissez le nom (obligatoire), l'e-mail et le téléphone (facultatifs).
- Modification et suppression fonctionnent de la même manière que dans les autres sections.

### Conditions de stockage

Définit des conditions de stockage spécifiques pouvant être assignées aux produits.

- **Nom** — étiquette descriptive (ex. : « Réfrigération 2–8 °C »)
- **Temp min / Temp max** — plage de température en °C (facultatif)
- **Humidité max** — humidité maximale en % (facultatif)
- **Sensible à la lumière** — activez ce bouton si le produit doit être protégé de la lumière

### Alertes

Configurez quand vous souhaitez recevoir des notifications :

- **Expiry alert days** — nombre de jours avant la péremption pour une alerte (vous pouvez ajouter plusieurs valeurs, ex. : 30, 60, 90 jours)
- **Reorder notifications** — activer/désactiver les alertes quand un produit atteint son point de réapprovisionnement
- **Critical stock notifications** — activer/désactiver les alertes quand un produit atteint son niveau critique

Appuyez sur **Save** pour confirmer les modifications.

---

## 10. Lecture de codes-barres

LabTrack peut lire les codes-barres et les codes QR dans plusieurs parties de l'application :

| Où | Pour quoi |
|----|-----------|
| Inventaire (barre d'application) | Rechercher un produit par code |
| Formulaire produit | Assigner un code-barres au produit |
| Enregistrement de mouvement | Sélectionner le produit à déplacer |
| Scan Count | Compter les produits en les scannant un par un |

Lors du premier appui sur l'icône scanner, l'application demande l'autorisation d'accès à la caméra. Pointez la caméra vers le code et il est lu automatiquement.

---

## 11. Synchronisation et utilisation hors ligne

LabTrack fonctionne entièrement hors ligne. Toutes les données sont stockées localement sur votre appareil.

Lorsqu'une connexion est disponible, l'application se synchronise automatiquement :

- À l'ouverture de l'onglet Inventaire
- Après l'enregistrement d'un mouvement
- Après la sauvegarde d'une session de comptage

La synchronisation est bidirectionnelle : les modifications effectuées sur un appareil apparaissent sur les autres appareils du même laboratoire dès que les deux sont en ligne.

> **Conseil :** Si vous travaillez en équipe, il est recommandé que chaque membre synchronise au début et à la fin de son service afin d'éviter les conflits de données.

---

## 12. Deux modes de gestion de laboratoire

LabTrack s'adapte à deux styles de travail distincts :

### Laboratoire avec suivi des mouvements

L'équipe enregistre chaque entrée, sortie et retour en temps réel.

**Avantages :**
- L'inventaire reflète toujours l'état actuel sans nécessiter de comptages fréquents.
- Le rapport de **Consommation** indique exactement la quantité utilisée de chaque produit.
- Les comptages périodiques servent d'**audit** : comparer ce que le système indique avec ce qui est physiquement présent (écarts).

**Flux de travail recommandé :**
1. Enregistrez les entrées à chaque réception de stock.
2. Enregistrez les sorties à chaque consommation d'un produit.
3. Effectuez un comptage mensuel pour détecter les écarts.
4. Consultez le rapport de Consommation pour analyser les tendances d'utilisation.

---

### Laboratoire avec comptages périodiques uniquement

L'équipe n'enregistre pas les mouvements individuels ; elle effectue plutôt des comptages complets réguliers de l'inventaire.

**Avantages :**
- Nécessite moins de rigueur au quotidien.
- Adapté aux cas où la consommation est très fréquente et où l'enregistrement individuel serait peu pratique.

**Flux de travail recommandé :**
1. Effectuez un comptage hebdomadaire ou mensuel depuis l'onglet **Count**.
2. Approuvez les ajustements à la fin du comptage pour que le système reflète la réalité.
3. Consultez le rapport de **Tendance** pour voir l'évolution de l'inventaire entre les comptages et inférer la consommation de la période.

---

## Glossaire

| Terme | Signification |
|-------|--------------|
| **Lot** | Ensemble d'un produit identifié par un numéro de lot et une date de péremption |
| **FEFO** | First Expired, First Out — le système classe les lots de la date de péremption la plus proche à la plus éloignée |
| **Stock minimum** | Niveau en dessous duquel le stock est considéré comme critique |
| **Point de réapprovisionnement** | Niveau préventif indiquant qu'il est temps de commander davantage |
| **Tracks lots** | Propriété du produit indiquant si son stock est géré par lots individuels |
| **Quantité directe** | Valeur de stock directe pour un produit qui n'utilise pas de lots |
| **Écart** | Différence entre la quantité attendue (système) et la quantité comptée physiquement |
| **Synchronisation** | Processus de mise en cohérence entre la base de données locale de l'appareil et le serveur cloud |

---

*LabTrack est développé avec Flutter + Supabase.*
