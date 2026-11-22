# 🛒🏎️ Mall Drift — prototype Roblox

Un jeu de karting à drift dans des centres commerciaux. On commence dans une petite supérette
et on monte jusqu'au méga centre commercial de Dubaï.

Ce prototype contient le **niveau 1 « Le Petit Marché »** avec :
- 3 karts (Basique, Chariot Turbo, Bolide Rouge) aux réglages différents
- le **drift** : grosses glissades, 360° possibles
- le **score de drift** : plus le drift est long et beau, plus il rapporte, avec des **étoiles ★★★**, un multiplicateur (combo), un **bonus 360°** et un **boost** après un beau drift
- le **sol mouillé** : ça glisse énormément, avec les **panneaux jaunes « ATTENTION SOL GLISSANT »** (on peut les renverser), un seau et une serpillière, des gerbes d'eau et des **éclaboussures sur l'écran**
- des cartons « PROMO » qu'on peut renverser
- le mode **jour / nuit**, la caméra **1re personne** (comme la vidéo TikTok)
- traces de pneus, fumée, sensation de vitesse

Les gardes de sécurité, la boutique et les niveaux suivants viendront ensuite (voir [`GAME_DESIGN.md`](GAME_DESIGN.md)).

---

## 🧩 Installer le jeu dans Roblox Studio (5 minutes)

Il y a **3 fichiers** à copier. Chacun va dans un endroit précis de Studio.

### Étape 0 — Ouvrir un nouveau jeu
1. Ouvre **Roblox Studio**.
2. Clique sur **Nouveau** puis choisis le modèle **Baseplate**.
3. En haut, onglet **Affichage (View)**, active **Explorateur (Explorer)** et **Propriétés (Properties)**.

### Étape 1 — Les réglages : `KartConfig`
1. Dans l'**Explorateur**, survole **ReplicatedStorage** et clique sur le **+**.
2. Choisis **ModuleScript**.
3. Renomme-le exactement **`KartConfig`** (clic droit > Renommer). Le nom est important !
4. Double-clique dessus, **efface tout** et colle le contenu de
   [`src/ReplicatedStorage/KartConfig.luau`](src/ReplicatedStorage/KartConfig.luau).

### Étape 2 — Le niveau et les karts : `MallDriftServer`
1. Survole **ServerScriptService**, clique sur le **+** et choisis **Script**.
2. Renomme-le **`MallDriftServer`**.
3. Efface tout et colle le contenu de
   [`src/ServerScriptService/MallDriftServer.server.luau`](src/ServerScriptService/MallDriftServer.server.luau).

### Étape 3 — La conduite : `KartController`
1. Ouvre **StarterPlayer**, survole **StarterPlayerScripts**, clique sur le **+** et choisis **LocalScript**
   (attention : **Local**Script, pas Script).
2. Renomme-le **`KartController`**.
3. Efface tout et colle le contenu de
   [`src/StarterPlayerScripts/KartController.client.luau`](src/StarterPlayerScripts/KartController.client.luau).

### Étape 4 — Jouer !
1. Clique sur **Play** (▶️).
2. Tu apparais à l'entrée du magasin. Approche-toi d'un kart et appuie sur **E** (« Conduire »).
3. Va drifter ! 🏁

> 💡 Si rien n'apparaît, ouvre la fenêtre **Sortie (Output)** (onglet Affichage) : tu dois voir
> `[Mall Drift] Niveau 1 « Le Petit Marché » construit`. S'il y a un message en rouge,
> copie-le-moi et je corrige.

---

## 🎮 Commandes

| Action | PC | Manette | Mobile |
|---|---|---|---|
| Avancer / reculer / tourner | Flèches ou ZQSD | Stick gauche | Joystick |
| **DRIFT** | **Maj (Shift)** | R2 / L2 | Bouton DRIFT |
| Caméra 1re personne | V | Y | Bouton CAM |
| Jour / nuit | N | — | — |
| Remettre le kart droit | R | X | Bouton R |
| Descendre du kart | Espace | A | Saut |

**Astuce pour faire un 360° :** prends un peu de vitesse, garde **Maj** enfoncé et tourne à fond.
Sur le sol mouillé, c'est encore plus facile, et ça rapporte **x1,5** points !

---

## 🔧 Changer le ressenti du jeu

Tout se règle dans **`KartConfig`**, sans toucher au reste :
- **le kart glisse trop** → augmente `AdherenceDrift` (ex. 1.4 → 2)
- **pas assez de glisse** → baisse `AdherenceDrift` (ex. 1.4 → 0.9)
- **trop lent** → augmente `VitesseMax` et `Acceleration`
- **les étoiles sont trop dures à avoir** → baisse les chiffres de `Etoiles = { 150, 500, 1200 }`
- **commencer le jour** → `Config.NuitParDefaut = false`
- **ajouter des sons** → dans Studio, ouvre la **Boîte à outils (Toolbox) > Audio**, cherche
  « tire screech » (crissement de pneus), « engine » (moteur), « splash » (éclaboussure),
  copie l'identifiant et colle-le dans `Config.Sons`

---

## 📁 Organisation des fichiers

```
mall-drift/
├── README.md               ← ce guide
├── GAME_DESIGN.md          ← le plan complet du jeu (niveaux, argent, idées)
└── src/
    ├── ReplicatedStorage/KartConfig.luau              (ModuleScript)
    ├── ServerScriptService/MallDriftServer.server.luau (Script)
    └── StarterPlayerScripts/KartController.client.luau (LocalScript)
```

Les noms de dossiers correspondent aux endroits de Roblox Studio. Plus tard, on pourra utiliser
**Rojo** pour synchroniser automatiquement ces fichiers avec Studio, sans copier-coller.
