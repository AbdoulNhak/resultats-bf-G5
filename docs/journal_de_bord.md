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
| 02/10 | Boîte `bento/ubuntu-24.04` épinglée à la version `202510.26.0` | La version de l'annexe (`202404.23.0`) n'était pas garantie au catalogue ; `202510.26.0` est disponible et le socle a été construit avec |
| 20/10 | Provisionneurs `commun`, `keepalived` et `obs` rejoués à chaque `vagrant up` ; `NB_APP` fixé dans `.env` | Activer E1 après coup laissait lb1 sans keepalived ; `/etc/hosts` et Prometheus doivent suivre `NB_APP` (R3) |
| 21/10 | Pannes simulées par `vagrant halt -f` dans V2, V4 et V6, relance automatique en fin de V2 et V6 | Panne brutale plus réaliste ; `vagrant halt` passe par SSH et avait échoué sur app1 |
| 21/10 | Contrôle keepalived par `systemctl is-active --quiet haproxy` au lieu de `pidof haproxy` | Le contrôle `pidof` échouait sous keepalived (voir difficultés) |
| 21/10 | Pour réduire `NB_APP` : détruire les VM en trop avant de baisser la valeur dans `.env` | Sinon Vagrant ne voit plus ces VM alors qu'elles tournent encore |
| 25/10 | Le rôle A reprend les mesures restantes du rôle D : idempotence (ticket 16), V5, conditions de mesure ; la rotation du rôle D (ticket 21) reste à sa charge | Mesures indispensables au rendu du 25/10 ; une rotation ne peut pas être faite par un autre membre |

## 3. Difficultés rencontrées et comment elles ont été levées

| Date | Difficulté | Solution | Qui |
|---|---|---|---|
| 03/10 | Section « Pull Requests » introuvable dans les réglages GitHub | Elle se trouve dans les réglages du **dépôt** (onglet Settings du dépôt), pas dans ceux du compte ; réglage aussi possible par `gh api` | B |
| 21/10 | V2 : script terminé sans rapport ; app1 restée « running » mais injoignable, SSH en échec (« timeout during server version negotiating ») | Panne simulée par `vagrant halt -f` (sans SSH) ; échec de l'arrêt journalisé au lieu d'interrompre le script ; relance automatique de la VM en fin de scénario | A |
| 21/10 | `vagrant up` en échec sur lb1 (installation de keepalived) : « Temporary failure resolving », DNS de la VM périmé après un changement de réseau du PC | `vagrant reload lb1` pour repartir ; correction durable : `--natdnshostresolver1 on` dans le Vagrantfile et nouvel essai automatique d'apt après un `apt-get update` forcé | A |
| 21/10 | E1 : l'IP virtuelle n'était portée par aucun répartiteur ; le contrôle `pidof haproxy` de keepalived échouait chaque seconde (`pidof` est un lien vers `killall5`, que keepalived exécute sous son vrai nom avec `enable_script_security`) | Contrôle remplacé par `systemctl is-active --quiet haproxy` ; lb1 repasse MASTER, V6 conforme | A |
| 21/10 | `vagrant destroy -f app3 app4` : « machine not found », car `NB_APP` avait déjà été remis à 2 dans `.env` | `NB_APP=4 vagrant destroy -f app3 app4` (la ligne de commande est prioritaire sur `.env`), puis `vagrant provision lb1` ; procédure corrigée dans le dossier (8.2) | A |
| 21/10 | V3 : la ligne SYNTHESE comptait deux fois les réponses 503 (« Failed » et « Non-2xx » d'`ab`) | Calcul corrigé dans `tests/v3_charge.sh` ; fichiers bruts conservés tels quels, écart expliqué dans le dossier (9.4) | A |
| 21-22/10 | V3 : 3 séries sur 7 en régime dégradé (12 à 13 req/s, 8,6 % à 43 % de réponses 503), les 4 autres sans erreur | Cause non établie ; séries publiées, comparaison faite sur le régime normal | A, D |
| 22/10 | V3 : le débit baisse en passant de 2 à 4 serveurs (52,0-54,9 contre 41,9-45,7 req/s) | `vmstat` sur bdd1 : processeur à 100 %, dont 92-94 % en temps système, donc coût de l'ouverture d'une connexion par requête ; goulet identifié (dossier 9.4) | A |
| 25/10 | `vagrant up` bloqué sur « Waiting for machine to boot » sur deux postes Windows ; VM démarrées, SSH actif dans les VM, mais rien n'écoute sur le port 2222 de l'hôte | Windows avait réservé la plage 2187-2286 (`netsh … excludedportrange`) ; VBox.log : « failed to set up redirection of 2222 to 22 ». Déblocage : `net stop winnat` / `vagrant up` / `net start winnat` ; correction durable : le Vagrantfile lit les plages réservées et attribue à chaque VM un port SSH libre à partir de 2722 | A |
| 25/10 | `tests/idempotence.sh` s'arrêtait sans rapport : le comptage SQL échouait sur les VM sans PostgreSQL et `set -e` coupait le script | Commandes distantes rendues tolérantes (`; true`, `|| true`), échec réel de `vagrant provision` affiché, progression visible ; résultat : OK, 18 empreintes identiques | A (ticket 16 du rôle D) |
| 25/10 | V5 : premier contrôle de `/sante` sans réponse en 2 s (code 000) juste après la reconstruction, `/resultat` à 200 l'instant d'après | Résultat publié tel quel et expliqué (dossier 9.6) ; reconstruction validée par le test d'idempotence qui a suivi | A |
| 26/10 | Ticket 23 : pare-feu jamais testé ; premier V1 avec pare-feu à 12/8 (écart 40 %) | Pare-feu activé (`PAREFEU=1`) et vérifié sur les 6 VM ; V1, V2, V4, V6 rejoués et conformes. Journal HAProxy du premier V1 : 20 requêtes à 200, aucune relance, 4 premières vers app1 puis alternance (état interne du tour de rôle, pas un échec) ; deux répétitions à 10/10. Pare-feu laissé désactivé par défaut | A (ticket 23 du rôle B) |
| 26/10 | Tickets 5 et 11 du rôle B non vérifiés : redémarrage automatique du service, retour de la base sans redémarrer l'application | Vérifiés : processus tué relancé par systemd (PID 2508 → 4460) ; base arrêtée puis relancée : `/sante` 200 → 503 JSON → 200 sans redémarrage de l'application (dossier, section 5) | A (tickets 5 et 11 du rôle B) |

## 4. Bilan

Le projet a abouti à une infrastructure Vagrant reproductible avec un répartiteur, deux serveurs applicatifs et deux bases PostgreSQL.
Les essais V1 à V6 ont documenté la répartition, les pannes applicative et de base, la reconstruction et la bascule du répartiteur.
V5 a reconstruit le socle sans intervention manuelle ; le test R2 a confirmé 18 empreintes identiques après deux rejeux.
L'incident de ports réservés par Windows a été diagnostiqué puis traité par l'attribution de ports SSH libres dans le Vagrantfile.
L'observabilité E2 reste non finalisée et le pare-feu n'est pas activé par défaut ; ces limites sont consignées dans le dossier d'architecture.
