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

- **Ton barbershop**, avec enseigne barbier qui tourne et ton nom + ta **note ⭐** sur la façade. Les clients **et clientes** entrent, s'assoient en **salle d'attente**, puis prennent un fauteuil dès qu'il se libère.
- **Patience** : une jauge **verte → rouge** au-dessus de chaque client. À zéro, il part fâché et laisse ★☆☆☆☆.
- **Tu coupes toi-même** : maintiens le clic (ou le doigt, ou R2 à la manette) sur la tête.
  - 🪒 **Tondeuse** à sabots #0 à #4 : fais tes dégradés toi-même. Débloquée par la Tondeuse Pro.
  - ✂️ **Ciseaux** : raccourcissent petit à petit.
  - 🔪 **Rasoir** : contours, crâne rasé.
  - 🎨 **Teinture** au pinceau.
  - Pinceau S / M / L, ↩️ annuler, 👁️ **modèle fantôme** superposé sur la tête.
  - Caméra : clic droit / Q-E / stick droit, molette pour zoomer.
- **Le modèle demandé est affiché en haut à droite** (tête 3D qui tourne), avec la **note en étoiles et le % de ressemblance en direct**, mèche par mèche.
- **Note de 1 à 5 étoiles** selon la qualité. La moyenne du salon fait venir les clients plus vite ou plus lentement.
- **Carte avant/après** dorée à chaque coupe.
- **Ménage** : chaque coupe laisse des cheveux par terre. Un salon sale rend les clients impatients et leur fait enlever une étoile. Tu commences au 🧹 **balai**, puis tu passes à l'**aspirateur** (aspire tout autour), puis au 🤖 **robot aspirateur** (automatique).
- **Tâches** : 3 objectifs en même temps (coupes, 5★, ménage, Battle, BarberTok, « sans perdre de client »…) avec récompenses.
- **Contenu** : **21 coupes** (dont 10 tendance TikTok), 7 dégradés, 5 barbes, 4 textures (lisses, bouclés, twists, locs), 18 couleurs.
- **Progression** :
  - améliorations : fauteuils, stylistes automatiques (qui gagnent même hors ligne), nettoyage, 5 niveaux de déco, publicité, Tondeuse Pro ;
  - **Franchise** : recommencer de zéro avec +50 % d'argent pour toujours.
- **Battle** toutes les ~3,5 min sur la grande scène : tout le monde a les mêmes cheveux trop longs et le même modèle, avec un chrono. Le score combine la précision, le vote du public et la vitesse. Un robot barbier joue si tu es seul.
- **BarberTok** : les coupes ≥ 90 % sont publiées en avant/après. Les likes donnent des abonnés (bonus d'argent), et une publication virale est annoncée à tout le serveur.
- **Barber Pass** : saison de 30 paliers, piste gratuite + piste Gold payante.
- **Miroir magique** : coupe libre sur toi-même. 🌱 fait repousser les cheveux, et tu peux changer de texture. Ton look est sauvegardé.

### 🔊 Sons et musique
Dans `Config.Sounds`, colle des IDs de la boutique Roblox (create.roblox.com → Creator Store → Audio) : tondeuse, ciseaux, aspirateur, balai, étoiles, **musique du salon** et **musique de Battle**. Tant qu'un ID est vide, un son intégré à Roblox est utilisé, et la musique reste coupée. Le bouton 🎵 du jeu coupe ou remet la musique.

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
src/shared/HairGrid.luau      Coupe aux mèches : cibles, score, encodage, rendu
src/shared/HairBuilder.luau   Coiffures « en bataille » légères des clients qui attendent
src/server/Salons.luau        Barbershops, clients ♂♀, stylistes, atelier, économie
src/server/Battle.luau        Battle de barbiers (scène, chrono, vote, robot)
src/server/BarberTok.luau     Réseau social : publications, likes, abonnés, viral
src/server/Progress.luau      XP, Barber Pass et tâches
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
