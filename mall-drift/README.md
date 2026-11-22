# ✦ Golden Mall Drift — prototype Roblox

Drifte en kart dans un **centre commercial géant à Dubaï**, fais monter ton niveau
et personnalise ton kart dans le **Garage VIP**.

Ce prototype contient :
- **Le Golden Mall** : des allées bordées de **48 boutiques où l'on entre en kart**, chacune avec
  un intérieur simple mais réaliste (coiffeur, vêtements, fast-food, jeux vidéo, téléphonie,
  sport, bijouterie, parfumerie, jouets, librairie, glacier, café), une place centrale avec
  **fontaine**, palmiers, kiosques et bancs, un **aquarium géant** avec des poissons, et un
  **food court**. Mannequins, chaises, cubes et ballons se renversent quand on les percute.
  Les noms de magasins sont inventés, car les vraies marques sont interdites sans autorisation.
- **Une caméra automatique** qui se place derrière le kart et tourne avec lui (plus besoin du clic droit)
- **Le drift** : grosses glissades et 360°, avec un score qui récompense les drifts longs et beaux.
  Les étoiles ★★★ se remplissent, un multiplicateur grimpe jusqu'à x5, chaque 360° donne un
  bonus, et un beau drift donne un boost
- **Le sol mouillé** : ça glisse énormément, avec les **panneaux jaunes « ATTENTION SOL GLISSANT »**
  qu'on peut renverser, des gerbes d'eau et des **éclaboussures sur l'écran**
- **La progression** : tes points de drift deviennent de l'**XP**, ton **niveau** monte, et chaque
  niveau débloque de nouveaux **karts, couleurs, finitions et autocollants**
- **Le Garage VIP** : ton kart tourne sur un **plateau** et tu le personnalises toi-même :
  modèle, carrosserie, finition (brillant, mat, métallisé, nacré, chrome), jantes, siège,
  bandes de course, autocollant et numéro
- **La sauvegarde** : niveau, record et kart personnalisé sont gardés d'une partie à l'autre
- Le **jour / la nuit**, la **caméra à la première personne** (comme les vidéos TikTok), les
  traces de pneus, la fumée et la sensation de vitesse

---

## ⚡ Méthode rapide (1 minute) : le fichier tout prêt

1. Télécharge le fichier **[`GoldenMallDrift.rbxlx`](GoldenMallDrift.rbxlx)** (sur GitHub : ouvre le fichier puis clique sur le bouton **Télécharger** ⬇️).
2. **Double-clique** dessus : Roblox Studio l'ouvre (ou dans Studio : **Fichier > Ouvrir depuis un fichier**).
3. Clique sur **Play** ▶️. C'est tout !

Les 5 scripts sont déjà rangés au bon endroit. Pour garder ta progression, fais ensuite
l'**étape 4** plus bas (publier le jeu et autoriser l'accès API).

---

## 🧩 Méthode manuelle (si le fichier ne s'ouvre pas)

Il y a **5 fichiers** à copier. Chacun va dans un endroit précis de Studio.

### Étape 0 — Ouvrir un nouveau jeu
1. Ouvre **Roblox Studio**, clique sur **Nouveau** puis sur le modèle **Baseplate**.
2. Onglet **Affichage (View)** : active **Explorateur (Explorer)** et **Sortie (Output)**.

### Étape 1 — Dans ReplicatedStorage : 2 ModuleScripts
Survole **ReplicatedStorage**, clique sur le **+**, choisis **ModuleScript**. Fais-le 2 fois :

| Nom exact (important !) | Contenu à coller |
|---|---|
| `KartConfig` | [`src/ReplicatedStorage/KartConfig.luau`](src/ReplicatedStorage/KartConfig.luau) |
| `KartBuilder` | [`src/ReplicatedStorage/KartBuilder.luau`](src/ReplicatedStorage/KartBuilder.luau) |

Pour renommer : clic droit > **Renommer**. Pour coller : double-clic sur le script,
**efface tout** (Ctrl+A puis Suppr), puis colle.

### Étape 2 — Dans ServerScriptService : 1 Script
Survole **ServerScriptService**, clique sur **+** et choisis **Script** :

| Nom | Contenu à coller |
|---|---|
| `MallDriftServer` | [`src/ServerScriptService/MallDriftServer.server.luau`](src/ServerScriptService/MallDriftServer.server.luau) |

### Étape 3 — Dans StarterPlayer > StarterPlayerScripts : 2 LocalScripts
Ouvre **StarterPlayer**, survole **StarterPlayerScripts**, clique sur **+** et choisis
**LocalScript** (bien **Local**Script !). Fais-le 2 fois :

| Nom | Contenu à coller |
|---|---|
| `KartController` | [`src/StarterPlayerScripts/KartController.client.luau`](src/StarterPlayerScripts/KartController.client.luau) |
| `GarageUI` | [`src/StarterPlayerScripts/GarageUI.client.luau`](src/StarterPlayerScripts/GarageUI.client.luau) |

### Étape 4 — Activer la sauvegarde (recommandé)
1. Enregistre le jeu sur Roblox : **Fichier > Publier sur Roblox**.
2. Onglet **Accueil > Paramètres du jeu > Sécurité** : active
   **« Autoriser l'accès Studio aux services API »**.

Sans cette étape, le jeu marche quand même, mais ton niveau repart à zéro à chaque partie.

### Étape 5 — Jouer !
1. Clique sur **Play** (▶️). Tu apparais dans le **Garage VIP**.
2. Va à l'**atelier** (la borne avec l'écran violet) :
   - **E** = personnaliser ton kart
   - **F** = sortir ton kart et partir drifter 🏁
3. Drifte, monte de niveau, puis reviens au garage pour débloquer de nouveaux styles !

> 💡 Dans la fenêtre **Sortie (Output)**, tu dois voir
> `[Golden Mall] Le Golden Mall de Dubaï est prêt !`. S'il y a un message en **rouge**,
> copie-le-moi et je corrige.

---

## 🎮 Commandes

| Action | PC | Manette | Mobile |
|---|---|---|---|
| Avancer / reculer / tourner | Flèches ou ZQSD | Stick gauche | Joystick |
| **DRIFT** | **Maj (Shift)** | R2 / L2 | Bouton DRIFT |
| Vue arrière / vue pilote | V | Y | Bouton CAM |
| Jour / nuit | N | — | — |
| Remettre le kart droit | R | X | Bouton R |
| Descendre du kart | Espace | A | Saut |
| Remonter dans son kart | E (près du kart) | — | Bouton à l'écran |

**Astuce 360° :** prends un peu de vitesse, garde **Maj** enfoncé et braque à fond. Sur le sol
mouillé autour de la fontaine, c'est encore plus facile, et ça rapporte **x1,5** points !

---

## 🔧 Régler le jeu (fichier `KartConfig`)

- **Le kart glisse trop** : monte `AdherenceDrift` (ex. 1.4 → 2)
- **Pas assez de glisse** : baisse `AdherenceDrift` (ex. 1.4 → 0.9)
- **Monter de niveau plus vite** : baisse les chiffres de `XPPourNiveauSuivant`
- **Une couleur se débloque plus tôt ou plus tard** : change son `Niveau` dans `Config.Couleurs`
- **Ajouter une couleur** : ajoute une ligne dans `Config.Couleurs`, elle apparaît toute seule au garage
- **Commencer le jour** : `Config.NuitParDefaut = false`
- **Caméra** : `Config.Camera` (distance, hauteur, souplesse du suivi)
- **Ajouter des sons** : dans Studio, **Boîte à outils (Toolbox) > Audio**, cherche « tire screech »,
  « engine », « splash », puis colle l'identifiant dans `Config.Sons`

---

## 📁 Fichiers

```
mall-drift/
├── README.md            ← ce guide
├── GAME_DESIGN.md       ← le plan du jeu (progression, garage, argent, idées)
└── src/
    ├── ReplicatedStorage/
    │   ├── KartConfig.luau                  (ModuleScript) réglages
    │   └── KartBuilder.luau                 (ModuleScript) fabrique les karts
    ├── ServerScriptService/
    │   └── MallDriftServer.server.luau      (Script) le mall, le garage, la sauvegarde
    └── StarterPlayerScripts/
        ├── KartController.client.luau       (LocalScript) conduite, drift, score
        └── GarageUI.client.luau             (LocalScript) menu du Garage VIP
```
