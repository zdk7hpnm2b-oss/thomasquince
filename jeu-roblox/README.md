# ✂️ Salon Star : Coiffure Tycoon (Roblox)

Jeu Roblox complet de **salon de coiffure** : des clients entrent avec une demande (coupe, longueur, couleur, accessoire), tu les coiffes dans un atelier en 3D, tu gagnes de l'argent, tu agrandis ton salon et tu engages des stylistes qui travaillent pour toi, même quand tu es hors ligne.

Tout est généré par code (bâtiments, coiffures, PNJ, interface) : **aucun asset à importer**, le jeu marche tel quel.

---

## 🚀 Ouvrir le jeu dans Roblox Studio (2 minutes)

1. Ouvre **`build/SalonStar.rbxlx`** dans Roblox Studio (double-clic ou Fichier → Ouvrir).
2. Clique sur **▶ Play**. La carte se construit au lancement (en mode édition, la carte est vide : c'est normal).
3. Pour publier : **Fichier → Publish to Roblox**.
4. Dans **Game Settings** :
   - **Security** → active *Enable Studio Access to API Services* (sinon pas de sauvegarde en test).
   - **Places → Server Size / Max Players** : mets **8** (il y a 8 salons par serveur).
   - **Avatar** : R15.

> Modifier le code : les sources sont dans `src/`. Avec [Rojo](https://rojo.space) : `rojo serve` puis le plugin Rojo dans Studio, ou recompile le fichier avec `rojo build default.project.json -o build/SalonStar.rbxlx`.

---

## 🎮 Comment on joue

| Étape | Ce que fait le joueur |
|---|---|
| 1 | Il arrive dans **son salon** (8 par serveur, nom du joueur sur l'enseigne). |
| 2 | Des **clients PNJ** entrent et s'assoient. Une bulle affiche leur demande et leur patience. |
| 3 | Il appuie sur **E** près du fauteuil → **atelier de coiffure** (caméra sur le visage, onglets Coupe / Longueur / Couleur / Accessoire, % de ressemblance en direct). |
| 4 | **Coiffure parfaite = +50 % de pourboire** et une **série** qui augmente encore les gains. |
| 5 | Il dépense son argent : fauteuils, stylistes automatiques, décoration (5 niveaux, du salon simple au palace doré avec tapis rouge), publicité, nouvelles coupes. |
| 6 | **Franchise** (renaissance) : repart de zéro avec +50 % d'argent pour toujours. |

**Côté social :**
- Les joueurs peuvent **s'asseoir dans le salon d'un autre** et se faire coiffer. Ils gardent la coiffure, qui est sauvegardée.
- Le **miroir magique** permet de changer son propre look.
- Une star arrive, un joueur lance l'Heure de Pointe… → **annonces à tout le serveur**.
- **Classement mondial** des meilleurs coiffeurs sur la place centrale.

**Contenu :** 11 coupes × 3 longueurs × 13 couleurs (dont néon et arc-en-ciel animé) × 5 accessoires, clients VIP, célébrités, cycle jour/nuit.

---

## 💰 Monétisation (à configurer)

Crée les passes et produits sur **create.roblox.com → ton jeu → Monétisation**, puis colle leurs IDs dans **`src/shared/Config.luau`** (`Config.GamePasses` et `Config.Products`). Tant qu'un ID vaut `0`, le bouton affiche « Bientôt ».

### Passes de jeu (achat unique)
| Pass | Effet | Prix conseillé |
|---|---|---|
| 👑 VIP | +50 % d'argent, vitesse, tag [VIP] dans le chat, 2× plus de clients VIP | 299 R$ |
| 💸 Argent x2 | double tous les gains | 399 R$ |
| 🌈 Couleurs Néon | teintures néon / or / arc-en-ciel, payées x3 par les clients | 149 R$ |
| 💎 Coiffures de Luxe | coupes Sirène et Royale + Couronne (les mieux payées) | 249 R$ |
| 🤖 Styliste Star | +2 stylistes gratuits | 199 R$ |
| ⚡ Clients Express | clients 40 % plus rapides | 99 R$ |
| 🪙 Gros Pourboires | pourboires x2 sur les coiffures parfaites | 99 R$ |

### Produits (achats répétables)
| Produit | Effet | Prix conseillé |
|---|---|---|
| 💵 💰 🏦 🏰 Packs d'argent | **calculés selon les gains du joueur** (10 min → 12 h de gains) : ils restent intéressants à chaque niveau | 25 / 79 / 199 / 499 R$ |
| 🔥 Heure de Pointe | clients x2 et paie x2 pour **tout le serveur** pendant 15 min, annoncé avec le nom de l'acheteur | 49 R$ |
| 🌟 Client Célébrité | une star arrive et paie x10 | 35 R$ |
| 🎁 Pack Débutant | 25K $ + coupe Bouclée + teintures fantaisie, proposé automatiquement après 1 min | 19 R$ |

Les achats sont **sécurisés** : chaque reçu est enregistré dans la sauvegarde du joueur, il ne peut pas être donné deux fois.

### Leviers gratuits déjà intégrés (rétention = algorithme Roblox)
- Bonus quotidien sur 7 jours (de x1 à x10)
- Cadeaux de temps de jeu (5, 15, 30, 60 min)
- Gains hors ligne grâce aux stylistes (jusqu'à 3 h) → les joueurs reviennent
- Boost amis (+10 % par ami, max +40 %), boost groupe (+10 %, mets ton `GroupId`), boost Premium (+10 % : les joueurs Premium te rapportent aussi des *Engagement Payouts*)
- Codes promo : `SALONSTAR`, `COIFFURE`, `MERCI` (modifiables dans `Config.Codes`)
- Bouton **Inviter des amis**

---

## 📈 Pour que le jeu décolle (checklist de lancement)

1. **Miniature et icône** : un personnage avec une coiffure néon arc-en-ciel très visible + texte court « COIFFE TES CLIENTS ! ». C'est le facteur n°1 du taux de clic.
2. **Titre** : `✂️ Salon Star [NOUVEAU]` puis `[MISE À JOUR 🌈]` à chaque mise à jour.
3. **Groupe Roblox** : crée-le, mets son ID dans `Config.GroupId`, et donne un code réservé aux membres.
4. **Publicités sponsorisées** : commence petit (quelques centaines de Robux par jour) le week-end, garde ce qui convertit.
5. **Mises à jour régulières** (toutes les 1–2 semaines) : nouvelle coupe, nouvelle couleur, nouveau code. Tout s'ajoute dans `Config.luau`.
6. **Équilibrage** : tous les prix et gains sont dans `Config.luau` (`Upgrades`, `Styles`, `BasePay`…).

> Personne ne peut garantir qu'un jeu Roblox marche : la mise en avant dépend de la rétention et du temps de jeu. Le jeu est conçu pour ça (boucle courte, objectifs constants, social, retour quotidien), mais la miniature et les mises à jour feront la différence.

---

## 🗂️ Structure

```
default.project.json        Projet Rojo (éclairage Future, etc.)
build/SalonStar.rbxlx       Fichier prêt à ouvrir dans Studio
src/shared/Config.luau      ⚙️ Équilibrage + IDs de monétisation
src/shared/HairBuilder.luau Générateur de coiffures 3D
src/shared/Util.luau        Formatage (1.5K, 2.3M…)
src/server/Main.server.luau Point d'entrée serveur
src/server/World.luau       Carte, terrain, éclairage, jour/nuit
src/server/Salons.luau      Salons, clients PNJ, stylistes, atelier, économie
src/server/Data.luau        Sauvegarde (verrou de session anti-duplication)
src/server/Stats.luau       Argent, multiplicateurs, état envoyé au client
src/server/Monetization.luau Passes et produits Robux
src/server/Rewards.luau     Quotidien, cadeaux, codes, amis/groupe, classement
src/client/Main.client.luau Interface, atelier, effets, tag VIP
src/client/Ui.luau          Composants d'interface
```

## 🧪 Tests

Les modules partagés (coiffures, formatage, équilibrage, interface) se testent hors de Studio avec [Lune](https://lune-org.github.io) :

```bash
lune run tests/modules.luau .
```
