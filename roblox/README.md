# Neon Bay (Roblox)

Jeu Roblox de coups et de poursuites dans une ville tropicale néon, inspiré de l'ambiance de GTA 6, en version cartoon pour les jeunes.

## Installation dans Roblox Studio

1. **La carte** : ouvre une place vide, supprime la Baseplate, puis View > Command Bar. Colle tout `NeonBay_Carte.lua` et appuie sur Entrée.
2. **Muscle Beach (serveur)** : dans ServerScriptService, ajoute un **Script** nommé `MuscleService` et colles-y `MuscleBeach/MuscleService.server.lua`.
3. **Muscle Beach (écran du joueur)** : dans StarterPlayer > StarterPlayerScripts, ajoute un **LocalScript** nommé `MuscleHUD` et colles-y `MuscleBeach/MuscleHUD.client.lua`.
4. **Les coups (serveur)** : dans ServerScriptService, ajoute un **Script** nommé `CoupService` et colles-y `Coups/CoupService.server.lua`.
5. **Les coups (écran du joueur)** : dans StarterPlayer > StarterPlayerScripts, ajoute un **LocalScript** nommé `CoupHUD` et colles-y `Coups/CoupHUD.client.lua`.
6. **Sauvegarde** : Game Settings > Security > active « Enable Studio Access to API Services ».
7. Clique sur **Play**. Pour tester Malins contre Gardiens, utilise l'onglet **Test** > **Clients and Servers** avec 2 joueurs.

## La boucle de jeu

1. **Malin** : maintenir le bouton 5 secondes devant la caisse d'une boutique pour prendre un butin. Plus tu es musclé, plus il vaut cher.
2. Les témoins te voient : 1 à 3 étoiles, ton visage sur les affiches « Recherché » et des étoiles au-dessus de ta tête.
3. Passer par la **cabine de déguisement** sur la plage pour perdre tes étoiles.
4. Déposer le butin à la **planque** (passerelle depuis le bout de la route) : billets + objet de collection, ×2 si un autre Malin est à côté.
5. **Gardien** : toucher un Malin qui a des étoiles. Il perd son butin, tu gagnes des billets.
6. Toutes les 8 minutes, tout le monde change de camp.

Une grosse flèche ▼ montre toujours où aller, et l'objectif s'affiche en bas de l'écran.

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
