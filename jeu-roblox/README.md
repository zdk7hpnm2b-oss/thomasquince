# 💈 Barber Legends (Roblox)

Jeu Roblox de **barbershop / salon de coiffure pour hommes et femmes**, avec les coupes tendance de 2026 (TikTok), des **Battles de barbiers** sur scène avec vote du public, et **BarberTok**, le réseau social intégré au jeu.

Tout est généré par code (bâtiments, coiffures, PNJ, interface) : **aucun asset à importer**.

---

## 🚀 Ouvrir le jeu (2 minutes)

1. Ouvre **`build/BarberLegends.rbxlx`** dans Roblox Studio.
2. Clique sur **▶ Play**. La carte se construit au lancement (en mode édition elle est vide, c'est normal).
3. **Fichier → Publish to Roblox**, puis dans **Game Settings** :
   - **Security** → *Enable Studio Access to API Services* (sinon pas de sauvegarde en test)
   - **Places → Max Players : 8** (8 barbershops par serveur)
   - **Avatar** : R15

> Modifier le code : sources dans `src/`, puis `rojo build default.project.json -o build/BarberLegends.rbxlx` (ou `rojo serve` + plugin Rojo).

---

## ✨ Ce qui rend le jeu différent

| | Les autres jeux de coiffure | Barber Legends |
|---|---|---|
| Public | surtout barbier homme **ou** salon femme | **les deux** : clients et clientes, coupes ♂ ♀ ⚥ |
| Coupes | coupes génériques | **tendances TikTok 2026** : French crop, Edgar, mulet, wolf cut, curtain, burst fade, butterfly, bob italien… avec badge 🔥 |
| Social | vote en fin de manche | **BarberTok** : fil type TikTok d'avant/après, likes, **abonnés = bonus d'argent**, publications **virales** annoncées au serveur, écran géant sur la place |
| Compétition | vote | **Battle** : même modèle pour tous, chrono, vote du public, **robot barbier** si tu es seul |
| Fin de coupe | – | **carte avant/après** dorée en 3D (style miniature) |

---

## 🎮 Gameplay

- **Ton barbershop** (enseigne barbier qui tourne, ton nom sur la façade). Des clients **et clientes** entrent avec une demande : coupe, longueur, **dégradé**, **barbe**, couleur, accessoire.
- **Atelier** (touche E près du fauteuil) : caméra face au visage, **tondeuse dans la main**, mèches qui tombent, % de ressemblance en direct. 6 onglets : Coupe / Longueur / Dégradé / Barbe / Couleur / Accessoire.
- **Coupe exacte** = pourboire +50 % + série qui augmente les gains.
- **Contenu** :
  - **26 coupes** (dont 13 tendance) ;
  - **7 dégradés** : taper, bas, moyen, haut, à blanc, burst ;
  - **5 barbes** ;
  - **18 couleurs** ;
  - **8 accessoires** : trait rasé, pince crabe, chaîne en or…
- **Progression** :
  - améliorations : fauteuils, stylistes automatiques (qui gagnent même hors ligne), 5 niveaux de déco (jusqu'au palace doré), publicité, Tondeuse Pro ;
  - **Franchise** : recommencer de zéro avec +50 % d'argent pour toujours.
- **Battle** toutes les ~3,5 min sur la grande scène. Le score combine la précision, les votes et la vitesse, et les gagnants touchent un prix.
- **BarberTok** :
  - chaque coupe ≥ 90 % de ressemblance (ou nouveau look) est publiée ;
  - chaque like = +1 abonné (+0,2 % d'argent par abonné, jusqu'à +50 %) ;
  - une publication virale rapporte un bonus et 10 abonnés.
- **Barber Pass** : saison de 30 paliers avec une piste gratuite et une piste **Gold** payante. L'XP vient des coupes, battles, likes et publications.

---

## 💰 Monétisation

Crée les passes et produits sur **create.roblox.com → ton jeu → Monétisation**, puis colle leurs IDs dans **`src/shared/Config.luau`**. Tant qu'un ID vaut `0`, le bouton affiche « Bientôt ».

### Passes (achat unique)
| Pass | Effet | Prix conseillé |
|---|---|---|
| 🎟️ Barber Pass Gold | piste Gold de la saison : x3 récompenses + teintures exclusives (Or rose, Chrome, Galaxie) | 299 R$ (à refaire à chaque saison : nouvel ID) |
| 👑 VIP | +50 % d'argent, vitesse, tag [VIP] dans le chat, 2× plus de clients VIP | 299 R$ |
| 💸 Argent x2 | double tous les gains | 399 R$ |
| 🌈 Couleurs Néon | néon, or, arc-en-ciel animé (payés x3) | 149 R$ |
| 💎 Coiffures de Luxe | Sirène, Royale + Couronne | 249 R$ |
| ⚔️ Battle Pro | gains de Battle x2 + 15 s de plus | 149 R$ |
| 🤖 Styliste Star | +2 stylistes gratuits | 199 R$ |
| ⚡ Clients Express | clients 40 % plus rapides | 99 R$ |
| 🪙 Gros Pourboires | pourboires x2 | 99 R$ |

### Produits (achats répétables)
| Produit | Effet | Prix conseillé |
|---|---|---|
| 💵 💰 🏦 🏰 Packs d'argent | calculés selon les gains du joueur (10 min → 12 h) | 25 / 79 / 199 / 499 R$ |
| ⏩ +5 paliers de Pass | avance dans le Barber Pass | 79 R$ |
| 🚀 Boost Viral | prochaine publication BarberTok épinglée en tête 10 min | 39 R$ |
| 🔥 Heure de Pointe | x2 clients et x2 paie pour **tout le serveur** 15 min (nom de l'acheteur annoncé) | 49 R$ |
| 🌟 Client Célébrité | une star qui paie x10 | 35 R$ |
| 🎁 Pack Débutant | 25K $ + Twists + Tondeuse Pro + teintures fantaisie (proposé après 1 min) | 19 R$ |

Achats sécurisés : chaque reçu est noté dans la sauvegarde, impossible de le recevoir deux fois.

**Gratuit (pour faire revenir les joueurs) :**
- bonus quotidien sur 7 jours ;
- cadeaux de temps de jeu ;
- gains hors ligne ;
- codes `SALONSTAR`, `COIFFURE`, `MERCI` ;
- boosts amis, groupe et Premium ;
- invitation d'amis.

**Nouvelle saison :** change `Config.Season` et `Config.SeasonName`, crée un nouveau pass Gold et mets son ID. Le nouveau pass est à racheter, comme dans les gros jeux.

---

## 📈 Checklist de lancement

1. **Miniature** : un gros plan avant/après sur fond doré (le jeu génère exactement ce visuel à chaque coupe : fais une capture), texte « BATTLE 💈 » ou « COUPE VIRALE 🔥 ».
2. **Titre** : `💈 Barber Legends [⚔️ BATTLES]`, puis `[🆕 SAISON 2]` à chaque saison.
3. **Groupe Roblox** : mets son ID dans `Config.GroupId`, code réservé aux membres.
4. **TikTok** : poste les meilleurs avant/après et les Battles (c'est fait pour être filmé).
5. **Mise à jour toutes les 1–2 semaines** : nouvelle coupe tendance (dans `Config.Styles`, avec `Trend = true`), nouveau code, nouvelle saison chaque mois.
6. Tout l'équilibrage est dans `Config.luau`.

> Aucun jeu n'a de succès garanti : Roblox met en avant les jeux qui gardent les joueurs. Le jeu est construit pour ça (boucle courte, Battles régulières, abonnés, pass saison, retour quotidien) ; la miniature et la régularité des mises à jour feront la différence.

---

## 🗂️ Structure

```
build/BarberLegends.rbxlx     Fichier prêt à ouvrir dans Studio
src/shared/Config.luau        ⚙️ Équilibrage, coupes, IDs de monétisation, saison
src/shared/HairBuilder.luau   Coiffures 3D : coupes, dégradés en bandes, barbes, accessoires
src/server/Salons.luau        Barbershops, clients ♂♀, stylistes, atelier, économie
src/server/Battle.luau        Battle de barbiers (scène, chrono, vote, robot)
src/server/BarberTok.luau     Réseau social : publications, likes, abonnés, viral
src/server/Progress.luau      XP et Barber Pass
src/server/Monetization.luau  Passes et produits Robux
src/server/Rewards.luau       Quotidien, cadeaux, codes, amis/groupe, classement
src/server/Data.luau          Sauvegarde (verrou de session anti-duplication)
src/server/Stats.luau         Argent, multiplicateurs, état client
src/server/World.luau         Carte, éclairage, jour/nuit
src/client/Main.client.luau   Interface, atelier, avant/après, BarberTok, Pass, effets
tests/modules.luau            Tests hors Studio (Lune)
```

## 🧪 Tests

```bash
lune run tests/modules.luau .
```
