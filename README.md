# Clip Finder GTA 6

Petit outil (une seule page web) pour trouver les vidéos YouTube GTA 6 qui décollent et repérer leurs temps forts à clipper.

## Ce qu'il fait
1. **Cherche les vidéos récentes** sur un mot-clé (par défaut « GTA 6 ») ou sur les chaînes de ton choix (`@JulienChieze`, …).
2. **Les classe par potentiel de clip** : vitesse de vues (vues par heure) et engagement (j'aime + commentaires).
3. **Trouve les temps forts** d'une vidéo en lisant ses commentaires : quand plusieurs spectateurs écrivent « 1:23:10 mdrrr », c'est un bon moment. L'outil regroupe ces horodatages et propose un passage d'environ 30 secondes.
4. **Bouton « Copier le lien + horaires »** à coller dans Opus Clip ou CapCut.

Il ne télécharge aucune vidéo : il passe uniquement par l'API officielle de YouTube.

## Utilisation
1. Télécharge `clip-finder.html` et ouvre-le avec Chrome, Edge ou Firefox (double-clic) sur un ordinateur.
2. Crée une clé API YouTube gratuite (les étapes sont expliquées dans la page), colle-la et clique sur « Enregistrer sur cet appareil ».
3. Lance une recherche, puis « Trouver les temps forts » sur une vidéo.

Quota gratuit : 10 000 unités par jour. Une recherche = environ 100 unités, une analyse de commentaires = 1 à 3 unités.

## Rappel
Clippe uniquement les créateurs qui t'ont donné leur accord ou qui ont une campagne de clipping, et crédite-les toujours.

---

# Veille automatique GTA 6 (`trend_watch.py`)

Programme lancé toutes les 2 heures par une tâche planifiée Claude. À chaque passage il :
- cherche sur **YouTube** les vidéos GTA 6 en français qui prennent le plus de vues par heure, plus les lives en cours ;
- liste sur **Twitch** les streams GTA VI francophones en direct et les **clips les plus vus** des dernières 24 h (avec le moment exact dans la VOD) ;
- écrit le rapport dans `reports/latest.md` et t'envoie une notification.

Clés nécessaires (stockées dans l'environnement cloud, jamais dans le code) :
- YouTube : secret réseau pour `www.googleapis.com`, en-tête `X-goog-api-key`.
- Twitch : secret réseau pour `api.twitch.tv` (`Authorization: Bearer <jeton d'application>`) + variable `TWITCH_CLIENT_ID`.

Lancer à la main : `python3 trend_watch.py` (options : `--hours 24`, `--lang fr`).
