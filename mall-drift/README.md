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
- **Arrivée dans le jeu** : le MENU s'ouvre directement (options à gauche, partie en direct en fond).
- **📖 Tuto sur la piste** (bouton TUTO du menu) : un kart (3, 2, 1) et une carte en haut de l'écran en
  **3 étapes** : accélère et tourne → drifte jusqu'à ⭐ → lâche le drift pour le BOOST
- **🎡 Roue du jour** (menu) : 1 tour GRATUIT par jour (2 avec le Pass VIP) + tours achetables. Cadeaux :
  pièces, XP, couleur, traînée, et le JACKPOT (kart Licorne Galaxie). Tirage fait par le serveur, chances
  affichées sous la roue (obligatoire sur Roblox pour un tirage au sort payant). Réglages : `Config.Roue`
- **🛒 Magasin à onglets** : ⭐ Offres (kart exclusif, 👑 Pass VIP pièces x2, Méga pack Légende, Pack de
  démarrage) · 🌈 Traînées (Feu, Arc-en-ciel, Étoiles, Éclair, Cœurs, Galaxie — aussi au garage, onglet DÉCO)
  · 🎡 Roue (3 ou 10 tours) · 💰 Pièces (1 000 à 15 000). Tout est dans `Config.Boutique`
- **❤️ 3 vies en Police contre Fugitifs** (police ET fugitifs). Quand on perd une vie : 🔄 RÉAPPARAÎTRE
  (gratuit) ou ⚡ VENGEANCE (payant, `Config.Partie.ProduitVengeance`) : celui qui t'a eu perd une vie.
  À 0 vie, on est éliminé. 3 s de protection en revenant. Cœurs affichés en haut de l'écran
- **🦄 Kart exclusif « Licorne Galaxie »** : uniquement en Robux (`Config.Karts.Galaxie.ProduitId`, ou l'offre
  `KartGalaxie` du magasin) : carrosserie arc-en-ciel animée, ailes néon, corne dorée, aileron lumineux,
  paillettes d'étoiles et traînée arc-en-ciel. Exposé dans le garage sur un socle lumineux
- **Graphismes poussés** : éclairage *Future* (réglé dans le .rbxlx ; sinon Lighting > Technology = Future),
  brume de sable de Dubaï, rayons du soleil, halo des néons et des enseignes, sol en marbre poli, spots avec
  ombres, rubans LED dorés sous les balcons ; sur le kart : phares, étincelles de drift (bleu → orange →
  violet selon les étoiles), flamme et lumière de boost, lignes de vitesse à l'écran
- **Garage façon « atelier de course »** : panneau sombre à droite, liseré rouge, un onglet par kart,
  PEINTURE (carrosserie / jantes / siège / bandes) · FINITIONS · DÉCO, cases avec leur prix, peintures
  premium et **✦ couleurs exclusives** (Licorne pastel, Galaxie, Lave, Glace polaire, Carbone, Bonbon rose)
- **💰 Pièces et peintures** : les pièces se gagnent en driftant (1 pour 20 points) et en jouant les modes.
  Au garage, les couleurs s'achètent avec des pièces (5 à 150 💰) et les **💎 peintures premium**
  (Chrome miroir, Or 24 carats, Arc-en-ciel animé, Rouge bonbon, Cyan néon, Vert toxique) en Robux.
  **🛒 Magasin** : Pack de démarrage et packs de pièces. Crée les produits sur le Creator Hub (Monétisation >
  Produits pour développeurs) et colle leurs numéros dans `Config.PeinturesPremium` et `Config.Boutique`
  (tant que le numéro est 0, l'achat est gratuit dans Studio pour tester)
- **Le menu** : à gauche « GOLDEN MALL DRIFT », un gros bouton rouge **JOUER** qui déplie les 3 modes
  (Entraînement, En ligne, Drift Battle), puis Garage, Magasin et Tuto. En bas à droite, l'offre du kart
  exclusif. En fond, la caméra **tourne en continu** autour des karts : les vrais joueurs du serveur
  (🔴 EN DIRECT) ou, s'il n'y en a pas (au lobby), des karts de démo qui driftent autour du mall
- **☰ Un menu pour choisir son mode** : en arrivant, tu visites le garage, puis tu ouvres **☰ MENU** (en bas à droite) :
  **🏁 ENTRAÎNEMENT** (drift libre, la police du mall en bots te poursuit), **🌐 JOUER EN LIGNE**
  (Police contre Fugitifs), **🔥 DRIFT BATTLE** (défi solo instantané : petit titre de 2 s, 3-2-1, puis
  1 minute pour faire le plus de points de drift ; score, record et XP à la fin, puis le
  **🏆 classement mondial** de tous les joueurs : le top 3 et directement ta place, par ex. « Tu es 200e ! ») et **🎨 GARAGE VIP**. Ceux qui s'entraînent continuent de rouler pendant
  les manches en ligne des autres
- **🎮 Mode en ligne « Police contre Fugitifs »** (dès 2 joueurs, jusqu'à 20) : quand assez de joueurs
  sont dans la file : une **page d'attente**
  (la caméra survole le mall, personne ne roule), puis le **tirage au sort** des équipes (moitié
  policiers 🚓, moitié fugitifs 🏃). L'entrée du mall se ferme ; les **fugitifs partent au sud**, la
  **police au nord** (à l'opposé). Feux 3, 2, 1, PARTEZ pour tous, mais la police reste bloquée
  8 secondes de plus. Un policier qui colle un fugitif l'**arrête** (il part au garage). **La police
  gagne** si tous les fugitifs sont arrêtés, sinon **les fugitifs gagnent** au bout de 5 minutes. XP pour
  tous, bonus pour les gagnants et pour chaque arrestation. Seul, un **bot de test** complète la partie
- **💨 Un beau drift = un boost** : ★ petit boost, ★★ boost moyen, ★★★ gros boost. Si la police te
  poursuit, c'est un **boost d'évasion** encore plus fort. À la fin de chaque manche Police vs Fugitifs :
  **classement des drifts** (total et meilleur drift) et bonus XP pour le **👑 Roi du drift**
- **🏬 Deux étages** : au-dessus du rez-de-chaussée, un **1er étage** avec ses propres boutiques. Au
  centre, un grand **atrium** ouvert sur les deux étages, traversé par une **passerelle**. On change d'étage
  en kart par **deux tapis roulants** au-dessus de la place centrale : celui de gauche **monte**, celui de
  droite **descend**, et ils t'emportent tout seuls. Garde-corps
  vitrés partout pour ne pas tomber
- **👥 Du monde partout** : un **vendeur à la caisse** de chaque boutique, des **clients** qui font leurs
  courses (ou assis chez le coiffeur), des gens sur les bancs et aux kiosques. Chaque boutique a une
  vraie **caisse** (caisse enregistreuse, écran, terminal de carte) ; les magasins de vêtements ont des
  **cabines d'essayage** ; nouvelle **supérette** avec rayons, frigos à boissons, fruits et caisse à tapis
- **🚨 La police du mall** : 3 policiers au rez-de-chaussée et 2 au 1er étage patrouillent **à pied**. Quand l'un d'eux voit ton kart (❗), il
  **saute dans son kart de police** (gyrophare bleu/rouge, « POLICE » sur les côtés) et te prend en
  chasse, presque aussi vite que toi. Il vise l'endroit où tu vas et appelle ses collègues en
  **renfort** (jusqu'à 🚨🚨🚨). S'il arrive tout près de toi : **ATTRAPÉ !**, retour au garage. Reste
  hors de vue quelques secondes pour le **semer** (+150 XP) : il redescend et repart à pied. Attire-le
  sur le **sol mouillé** : il glisse (+100 XP) 😂. À pied, tu es un client normal ; dehors, tu es à l'abri
- **Le départ** : en appuyant sur **F** (ou « SORTIR MON KART »), la caméra **survole un coin de la map**
  pendant 3 secondes (fontaine, aquarium, boutiques, food court ou soldes, au hasard), puis plonge
  derrière ton kart sur la **ligne de départ à l'intérieur du mall**. Les feux du portique s'allument :
  **3, 2, 1… PARTEZ !**
- **Des obstacles** : slalom de plots, caddies abandonnés, palettes de cartons « PROMO », panneaux
  « SOLDES », zone de travaux en chicane, et deux **autolaveuses** qui circulent en laissant une
  traînée d'eau glissante derrière elles. Le 1er étage a aussi ses obstacles, flaques et autolaveuse
- **Prêt pour 20 joueurs** : grille de départ de 24 places (3 rangées de 8)
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

Les 12 scripts sont déjà rangés au bon endroit. Pour garder ta progression, fais ensuite
l'**étape 4** plus bas (publier le jeu et autoriser l'accès API).

---

## 🧩 Méthode manuelle (si le fichier ne s'ouvre pas)

Il y a **12 fichiers** à copier. Chacun va dans un endroit précis de Studio.

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

### Étape 2 — Dans ServerScriptService : 5 Scripts
Survole **ServerScriptService**, clique sur **+** et choisis **Script**. Fais-le 5 fois :

| Nom | Contenu à coller |
|---|---|
| `MallDriftServer` | [`src/ServerScriptService/MallDriftServer.server.luau`](src/ServerScriptService/MallDriftServer.server.luau) |
| `SecuriteServer` | [`src/ServerScriptService/SecuriteServer.server.luau`](src/ServerScriptService/SecuriteServer.server.luau) |
| `PNJServer` | [`src/ServerScriptService/PNJServer.server.luau`](src/ServerScriptService/PNJServer.server.luau) |
| `ManchesServer` | [`src/ServerScriptService/ManchesServer.server.luau`](src/ServerScriptService/ManchesServer.server.luau) |
| `MatchmakingServer` | [`src/ServerScriptService/MatchmakingServer.server.luau`](src/ServerScriptService/MatchmakingServer.server.luau) |

### Étape 3 — Dans StarterPlayer > StarterPlayerScripts : 5 LocalScripts
Ouvre **StarterPlayer**, survole **StarterPlayerScripts**, clique sur **+** et choisis
**LocalScript** (bien **Local**Script !). Fais-le 5 fois :

| Nom | Contenu à coller |
|---|---|
| `KartController` | [`src/StarterPlayerScripts/KartController.client.luau`](src/StarterPlayerScripts/KartController.client.luau) |
| `GarageUI` | [`src/StarterPlayerScripts/GarageUI.client.luau`](src/StarterPlayerScripts/GarageUI.client.luau) |
| `Tutoriel` | [`src/StarterPlayerScripts/Tutoriel.client.luau`](src/StarterPlayerScripts/Tutoriel.client.luau) |
| `SecuriteUI` | [`src/StarterPlayerScripts/SecuriteUI.client.luau`](src/StarterPlayerScripts/SecuriteUI.client.luau) |
| `PartieUI` | [`src/StarterPlayerScripts/PartieUI.client.luau`](src/StarterPlayerScripts/PartieUI.client.luau) |

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

## 🌍 Publier en plusieurs places (lobby + places de jeu)

Le jeu peut tourner de deux façons :
- **Tout dans une seule place** (par défaut, `Config.Places.Lobby = 0`) : pratique pour tester dans Studio.
- **Une expérience avec plusieurs places**, comme les gros jeux Roblox :

| Place | Rôle |
|---|---|
| 🏠 **Lobby** (place de départ, publique) | On arrive, on visite le garage, on choisit son mode dans le menu |
| 🏁 **Entraînement** | Drift libre avec la police bot (le kart t'attend sur la ligne de départ) |
| 🚓 **Police contre Fugitifs** | Le matchmaking du lobby y envoie les groupes (jusqu'à 20) sur un serveur privé |
| 🔥 **Drift Battle** | Le défi solo + le classement mondial, puis retour au lobby |
| ➕ **Jeu4** | Réservée pour un 4e mode |

Les places de jeu ne sont pas accessibles directement : seul le lobby y envoie les joueurs, et à la
fin d'une partie, on revient au lobby (le menu s'ouvre tout seul).

**Mise en place (une seule fois) :**
1. Publie le fichier `GoldenMallDrift.rbxlx` : **Fichier > Publier sur Roblox** → nouvelle expérience.
   Cette première place devient le **Lobby**.
2. Sur le **Creator Hub** (create.roblox.com) > ton expérience > **Places** > **Ajouter une place** :
   crée 3 places (**Entraînement**, **Police contre Fugitifs**, **Drift Battle**). Note le **numéro
   (ID)** de chaque place, y compris celui du lobby.
3. Dans Studio, ouvre `KartConfig` et remplis `Config.Places` avec ces 4 numéros.
4. Publie **le même fichier dans chaque place** : **Fichier > Publier sur Roblox en tant que…** →
   choisis ton expérience → choisis la place à remplacer. Fais-le pour les 4 places.
5. **Paramètres du jeu > Sécurité** : active **l'accès aux services API** (sauvegarde + classement).
6. Nombre max de joueurs conseillé : Lobby 40, Police contre Fugitifs 20, Entraînement 20, Drift Battle 10.

⚠️ Les téléportations entre places ne marchent **que dans le jeu publié** (pas dans Studio).
Pour tester dans Studio, remets `Config.Places.Lobby = 0` (tout dans une seule place).

---

## 👥 Tester le mode en ligne dans Studio

**Seul, avec un bot** : c'est activé par défaut (`Config.Partie.BotsTest = 1`). Lance **Play**, puis
dans le menu, choisis **🌐 JOUER EN LIGNE** : un bot rejoint la partie et le tirage au sort se fait entre toi et lui. Si le bot est
policier 🤖🚓, il te poursuit ; s'il est fugitif 🤖🏃, c'est à toi de l'attraper. **Avant de publier le
jeu pour de vrai, remets `BotsTest = 0`** (sinon les joueurs seuls enchaînent des manches contre un bot).

**À plusieurs :**

Onglet **Test** > zone **Clients et serveurs** : choisis **2 joueurs** (ou plus) puis clique sur
**Démarrer**. Studio ouvre une fenêtre par joueur : au bout de 20 secondes, le tirage au sort se lance.

Pour jouer pour de vrai : **Fichier > Publier sur Roblox**, puis **Paramètres du jeu > Places** :
nombre max de joueurs = **20**.

---

## 🎮 Commandes

| Action | PC | Manette | Mobile |
|---|---|---|---|
| Avancer / reculer / tourner | Flèches ou ZQSD | Stick gauche | Joystick |
| **DRIFT** | **Maj (Shift)** | R2 / L2 | Bouton DRIFT |
| Vue arrière (3e personne) / caméra GoPro | V | Y | Bouton CAM |
| Jour / nuit | N | — | — |
| Remettre le kart droit | R | X | Bouton R |
| **Prendre son kart (ligne de départ)** | **F** | Y | Bouton 🏎️ CONDUIRE |
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
    │   ├── SecuriteServer.server.luau       (Script) la police
    │   ├── PNJServer.server.luau            (Script) les vendeurs et les clients
    │   ├── ManchesServer.server.luau        (Script) Police vs Fugitifs, Drift Battle
    │   └── MatchmakingServer.server.luau    (Script) lobby → places de jeu (téléportations)
    └── StarterPlayerScripts/
        ├── KartController.client.luau       (LocalScript) conduite, drift, score
        ├── GarageUI.client.luau             (LocalScript) menu du Garage VIP
        ├── Tutoriel.client.luau             (LocalScript) tuto sur la piste, 3 étapes
        ├── SecuriteUI.client.luau           (LocalScript) alertes de la police
        └── PartieUI.client.luau             (LocalScript) écrans du mode en ligne
```
