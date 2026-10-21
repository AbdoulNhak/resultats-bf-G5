# Journal de bord - RÉSULTATS-BF

**Groupe 5** · Master 1 Informatique - Virtualisation et Cloud Computing · Dr SOMDA · Rendu le 25 octobre 2026

Livrable L3 (1 à 2 pages). Tenu par le rôle B ; chaque membre ajoute ses
entrées au fil de l'eau, par pull request.

## 1. Répartition des rôles

| Membre | Rôle | Périmètre | Extension | Commit hors domaine (rotation) |
|---|---|---|---|---|
| … | A - Architecte réseau, répartition et intégration | Vagrantfile, HAProxy, sonde de santé, Git, reconstruction (R1, R3, R4, R8) | E1 | Script de charge `tests/v3_charge.sh` |
| … | B - Ingénieur applicatif, sécurité et documentation | Application, secrets, pare-feu, README, dossier, journal (R7, R8) | - | Relecture de `scripts/bascule.sh` |
| … | C - Ingénieur données | PostgreSQL, jeu de données, réplication, bascule (R5, R6) | E3 (réserve) | Requête SQL de `/resultat` |
| … | D - Essais et observabilité | Scénarios V1 à V6, mesures, idempotence (R2) | E2 | Provisionnement de lb2 (`keepalived.sh`) |

**Organisation.** Un ticket GitHub (issue) par tâche, rattaché à un jalon
(J1 : 7 oct., J2 : 13 oct., J3 : 19 oct., rendu : 25 oct.). Chaque membre crée
une branche par ticket et ouvre une pull request relue par un membre d'un autre
rôle avant fusion dans `main`. Cette relecture croisée prépare la soutenance,
où l'enseignant interroge n'importe quel membre sur n'importe quelle partie.

## 2. Décisions prises et pourquoi

| Date | Décision | Pourquoi |
|---|---|---|
| 01/10 | Application en Python (Flask + gunicorn), paquets installés par `apt` | Paquets présents dans Ubuntu 24.04 : pas de dépendance à PyPI, installation plus sûre sur connexion lente |
| 01/10 | Extensions E1 (répartiteur redondant) et E2 (observabilité) ; E3 en réserve | V6 exige E1 ; E2 rend les pannes et la charge visibles en démonstration |
| 01/10 | Source unique de vérité : table `NOEUDS` du Vagrantfile → `config/noeuds.yml` | Exigence R3 et pénalité pour adresses en dur ; une seule valeur (`NB_APP`) à changer |
| 01/10 | Création automatique de `.env` avec des mots de passe aléatoires | Concilier R1 (aucun geste manuel) et R7 (aucun secret dans le dépôt) |
| 01/10 | Chaîne de connexion « bdd1, bdd2 » avec `target_session_attrs=read-write` | La bascule de la base se réduit à promouvoir bdd2 ; aucune modification des serveurs applicatifs |
| 02/10 | Équipe de 4 au lieu de 5 : retour aux 4 rôles du sujet | Les tâches d'intégration et de documentation sont réparties entre les rôles A, B et D |
| 03/10 | Suivi par tickets GitHub, une branche par ticket, pull request relue par un autre rôle | Historique lisible, contribution de chacun visible, relecture croisée |
| 03/10 | Fusion en « merge commit » uniquement (squash et rebase désactivés) | Conserver dans l'historique les commits de chaque membre (preuve de la rotation) |
| 03/10 | Pas de partage du fichier de la boîte par clé USB : chacun la télécharge via `vagrant up` | Une boîte ajoutée depuis un fichier perd son numéro de version épinglée ; et chaque poste teste ainsi R1 en conditions réelles |
| | `[À COMPLÉTER au fil du projet]` | |

## 3. Difficultés rencontrées et comment elles ont été levées

| Date | Difficulté | Solution | Qui |
|---|---|---|---|
| 03/10 | Section « Pull Requests » introuvable dans les réglages GitHub | Elle se trouve dans les réglages du **dépôt** (onglet Settings du dépôt), pas dans ceux du compte ; réglage aussi possible par `gh api` | B |
| | `[À COMPLÉTER - ex. : version de boîte introuvable, réseau hôte-seul refusé, service qui n'écoute que sur 127.0.0.1, fins de ligne CRLF…]` | | |

## 4. Bilan

`[À RÉDIGER en fin de projet - 5 à 6 lignes : ce qui a bien fonctionné dans
l'organisation, ce que nous changerions, ce que chacun a appris]`
