# Neon Bay (Roblox)

Jeu Roblox de coups et de poursuites dans une ville tropicale néon, inspiré de l'ambiance de GTA 6, en version cartoon pour les jeunes.

## Installation dans Roblox Studio

1. **La carte** : ouvre une place vide, supprime la Baseplate, puis View > Command Bar. Colle tout `NeonBay_Carte.lua` et appuie sur Entrée.
2. **Muscle Beach (serveur)** : dans ServerScriptService, ajoute un **Script** nommé `MuscleService` et colles-y `MuscleBeach/MuscleService.server.lua`.
3. **Muscle Beach (écran du joueur)** : dans StarterPlayer > StarterPlayerScripts, ajoute un **LocalScript** nommé `MuscleHUD` et colles-y `MuscleBeach/MuscleHUD.client.lua`.
4. **Sauvegarde** : Game Settings > Security > active « Enable Studio Access to API Services ».
5. Clique sur **Play** et va sur la plage, à l'arche « MUSCLE BEACH ».

L'avatar grossit seulement avec les avatars **R15** (réglage par défaut des nouveaux jeux).

## Muscle Beach

| Appareil | Force requise | Gain par répétition |
| --- | --- | --- |
| Haltères | 0 | +1 |
| Sac de frappe | 50 | +3 |
| Tapis de course | 200 | +6 |
| Développé couché | 800 | +15 |
| Le Monstre | 3 000 | +40 |

Les valeurs se changent dans les attributs de chaque appareil (Workspace > NeonBay > Plage > MuscleBeach) ou dans le tableau `appareils` de `NeonBay_Carte.lua`. Les autres réglages (taille maximale, fonte des muscles) sont en haut de `MuscleService.server.lua`.
