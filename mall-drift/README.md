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
- **Le style des vidéos TikTok « Drift Kart »** : caméra **GoPro sur la poitrine** en grand angle
  (on voit le volant, les mains et les jambes), elle penche dans les drifts et tremble à pleine
  vitesse ; **néons sous le kart** qui éclairent le sol ; petit écran sur le volant ; plafond blanc
  avec puits de lumière et spots, **grand carrelage brillant**, magasins fermés par des rideaux métalliques
- **🚨 La police du mall** : 3 policiers patrouillent **à pied**. Quand l'un d'eux voit ton kart (❗), il
  **saute dans son kart de police** (gyrophare bleu/rouge, « POLICE » sur les côtés) et te prend en
  chasse, presque aussi vite que toi. Il vise l'endroit où tu vas et appelle ses collègues en
  **renfort** (jusqu'à 🚨🚨🚨). S'il arrive tout près de toi : **ATTRAPÉ !**, retour au garage. Reste
  hors de vue quelques secondes pour le **semer** (+150 XP) : il redescend et repart à pied. Attire-le
  sur le **sol mouillé** : il glisse (+100 XP) 😂. À pied, tu es un client normal ; dehors, tu es à l'abri
- **Le départ dans le hall** : en entrant dans le garage, une bannière « GARAGE VIP » s'affiche ; en
  ouvrant le menu, la caméra glisse jusqu'au plateau. Quand tu prends ton kart au garage, tu arrives
  **au milieu du hall** sur une **ligne de départ** : la caméra fait le tour de ton kart, puis les
  feux du portique s'allument **3, 2, 1… PARTEZ !**
- **Une intro cinématique** (~6 s) à l'arrivée : la caméra tourne autour de la fontaine puis survole
  le parking jusqu'au garage, avec le titre du jeu (bouton « Passer »)
- **Monter dans son kart en 1 clic** : gros bouton **🏎️ CONDUIRE** ou touche **F**, n'importe où.
  Le kart apparaît sous toi et tu es assis automatiquement
- **Le Garage VIP est un grand bâtiment à part**, dehors, au bout du parking devant l'entrée du
  mall : plateau tournant, borne de personnalisation, vitrine des karts à débloquer
- **Une caméra automatique** qui suit le kart (plus besoin du clic droit). **V** passe de la GoPro à la vue arrière
- **Le drift** : grosses glissades et 360°, avec un score qui récompense les drifts longs et beaux.
  Les étoiles ★★★ se remplissent, un multiplicateur grimpe jusqu'à x5, chaque 360° donne un
  bonus, et un beau drift donne un boost
- **Le sol mouillé** : ça glisse énormément, avec les **panneaux jaunes « ATTENTION SOL GLISSANT »**
  qu'on peut renverser, des gerbes d'eau et des **éclaboussures sur l'écran**
- **La progression** : tes points de drift deviennent de l'**XP**, ton **niveau** monte, et chaque
  niveau débloque de nouveaux **karts, couleurs, finitions et autocollants**
- **Le Garage VIP** : ton kart tourne sur un **plateau** et tu le personnalises toi-même :
  modèle, carrosserie, finition (brillant, mat, métallisé, nacré, chrome), **néons** (dont arc-en-ciel), jantes, siège,
  bandes de course, autocollant et numéro
- **La sauvegarde** : niveau, record et kart personnalisé sont gardés d'une partie à l'autre
- Le **jour / la nuit**, la **caméra à la première personne** (comme les vidéos TikTok), les
  traces de pneus, la fumée et la sensation de vitesse

---

## ⚡ Méthode rapide (1 minute) : le fichier tout prêt

1. Télécharge le fichier **[`GoldenMallDrift.rbxlx`](GoldenMallDrift.rbxlx)** (sur GitHub : ouvre le fichier puis clique sur le bouton **Télécharger** ⬇️).
2. **Double-clique** dessus : Roblox Studio l'ouvre (ou dans Studio : **Fichier > Ouvrir depuis un fichier**).
3. Clique sur **Play** ▶️. C'est tout !

Les 8 scripts sont déjà rangés au bon endroit. Pour garder ta progression, fais ensuite
l'**étape 4** plus bas (publier le jeu et autoriser l'accès API).

---

## 🧩 Méthode manuelle (si le fichier ne s'ouvre pas)

Il y a **8 fichiers** à copier. Chacun va dans un endroit précis de Studio.

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

### Étape 2 — Dans ServerScriptService : 2 Scripts
Survole **ServerScriptService**, clique sur **+** et choisis **Script**. Fais-le 2 fois :

| Nom | Contenu à coller |
|---|---|
| `MallDriftServer` | [`src/ServerScriptService/MallDriftServer.server.luau`](src/ServerScriptService/MallDriftServer.server.luau) |
| `SecuriteServer` | [`src/ServerScriptService/SecuriteServer.server.luau`](src/ServerScriptService/SecuriteServer.server.luau) |

### Étape 3 — Dans StarterPlayer > StarterPlayerScripts : 4 LocalScripts
Ouvre **StarterPlayer**, survole **StarterPlayerScripts**, clique sur **+** et choisis
**LocalScript** (bien **Local**Script !). Fais-le 4 fois :

| Nom | Contenu à coller |
|---|---|
| `KartController` | [`src/StarterPlayerScripts/KartController.client.luau`](src/StarterPlayerScripts/KartController.client.luau) |
| `GarageUI` | [`src/StarterPlayerScripts/GarageUI.client.luau`](src/StarterPlayerScripts/GarageUI.client.luau) |
| `Intro` | [`src/StarterPlayerScripts/Intro.client.luau`](src/StarterPlayerScripts/Intro.client.luau) |
| `SecuriteUI` | [`src/StarterPlayerScripts/SecuriteUI.client.luau`](src/StarterPlayerScripts/SecuriteUI.client.luau) |

### Étape 4 — Activer la sauvegarde (recommandé)
1. Enregistre le jeu sur Roblox : **Fichier > Publier sur Roblox**.
2. Onglet **Accueil > Paramètres du jeu > Sécurité** : active
   **« Autoriser l'accès Studio aux services API »**.

Sans cette étape, le jeu marche quand même, mais ton niveau repart à zéro à chaque partie.

### Étape 5 — Jouer !
1. Clique sur **Play** (▶️). L'intro se lance, puis tu apparais dans le **Garage VIP** (dehors, devant le mall).
2. Appuie sur **F** ou sur le gros bouton **🏎️ CONDUIRE** : ton kart apparaît et tu es dedans.
3. Pour personnaliser ton kart : la **borne de l'atelier** (écran violet) dans le garage, touche **E**.
4. Sors du garage, traverse le parking et entre dans le mall par la grande entrée. Bon drift ! 🏁

> 💡 Dans la fenêtre **Sortie (Output)**, tu dois voir
> `[Golden Mall] Le Golden Mall de Dubaï est prêt !`. S'il y a un message en **rouge**,
> copie-le-moi et je corrige.

---

## 🎮 Commandes

| Action | PC | Manette | Mobile |
|---|---|---|---|
| Avancer / reculer / tourner | Flèches ou ZQSD | Stick gauche | Joystick |
| **DRIFT** | **Maj (Shift)** | R2 / L2 | Bouton DRIFT |
| Caméra GoPro / vue arrière | V | Y | Bouton CAM |
| Jour / nuit | N | — | — |
| Remettre le kart droit | R | X | Bouton R |
| **Sortir / reprendre son kart** | **F** | Y | Bouton 🏎️ CONDUIRE |
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
    │   ├── MallDriftServer.server.luau      (Script) le mall, le garage, la sauvegarde
    │   └── SecuriteServer.server.luau       (Script) les gardes de sécurité
    └── StarterPlayerScripts/
        ├── KartController.client.luau       (LocalScript) conduite, drift, score
        ├── GarageUI.client.luau             (LocalScript) menu du Garage VIP
        ├── Intro.client.luau                (LocalScript) intro cinématique
        └── SecuriteUI.client.luau           (LocalScript) alertes de la sécurité
```
