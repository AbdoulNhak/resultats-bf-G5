# Tickets du projet RÉSULTATS-BF - Groupe 5

30 tickets répartis sur 4 jalons. Créés automatiquement par `outils/creer_tickets_github.sh`.

## J1 - vagrant up de bout en bout (07/10)

Le socle (bdd1, bdd2, app1, app2, lb1) démarre sans geste manuel.

| N° | Rôle | Ticket | Critères de fin |
|---|---|---|---|
| 1 | tous | **Installer l'environnement et réussir vagrant up sur son poste** - Chaque membre installe VirtualBox 7, Vagrant 2.4 et Git, ajoute la boîte partagée et démarre le socle. | Virtualisation (VT-x/AMD-V) activée dans le BIOS, Hyper-V désactivé sous Windows<br>`vagrant box list` affiche bento/ubuntu-24.04 à la version épinglée<br>`vagrant up` réussi, `curl http://192.168.60.11/info` répond<br>Chaque membre coche son nom en commentaire du ticket |
| 2 | role-A | **Initialiser le dépôt GitHub et la protection de main** - Dépôt privé, squelette poussé, collaborateurs invités, labels, jalons, tableau Projects, règle de protection de main. | Squelette poussé sur main avec .gitattributes et .gitignore<br>Les 3 autres membres ont accepté l'invitation<br>Ruleset : PR obligatoire avec 1 approbation, pas de force push<br>Fusion « merge commit » seulement, suppression auto des branches |
| 3 | role-A | **Vérifier et épingler la version de la boîte bento/ubuntu-24.04** - La version de l'annexe (202404.23.0) n'existe peut-être plus. Choisir une version disponible, l'épingler dans le Vagrantfile. | `vagrant box add bento/ubuntu-24.04 --box-version <version>` réussit<br>VERSION mise à jour dans le Vagrantfile |
| 4 | role-A | **Premier vagrant up du socle et corrections** - Faire tourner le squelette sur VirtualBox pour la première fois et corriger tout ce qui bloque. | Les 5 VM démarrent sans erreur ni commande manuelle<br>`/info` alterne entre app1 et app2 via lb1<br>Corrections poussées par PR, problèmes notés dans le journal de bord |
| 5 | role-B | **Tester l'application : /info, /sante, /resultat** - Vérifier les trois points d'entrée sur app1 et app2, et comprendre chaque ligne de app/app.py. | /resultat?matricule=BF000123 renvoie un JSON correct<br>Matricule invalide → 400, inconnu → 404<br>Service gunicorn actif et redémarré automatiquement (systemctl) |
| 6 | role-C | **Vérifier bdd1 : schéma, 50 000 lignes et comptes** - Contrôler le jeu de données et les rôles PostgreSQL créés par scripts/bdd.sh. | `SELECT count(*) FROM resultats` = 50 000<br>Le rôle app ne peut que lire (SELECT)<br>Données hors de /vagrant (piège n°3) |
| 7 | role-D | **Schéma d'architecture pour le dossier** - Dessiner l'architecture cible (lb, app, bdd, obs, flux, adresses du groupe 5). | Schéma exporté en PNG dans docs/<br>Adresses 192.168.60.x et ports indiqués |

## J2 - V1 et V2 passent (13/10)

Répartition et sonde de santé opérationnelles, réplication en place.

| N° | Rôle | Ticket | Critères de fin |
|---|---|---|---|
| 8 | role-A | **Valider la configuration HAProxy engendrée et la sonde /sante (R4)** - Vérifier que la configuration vient bien de config/noeuds.yml et que la sonde écarte un serveur en moins de 5 s. | Aucune adresse d'app écrite en dur<br>Page de statistiques http://192.168.60.11:8404 consultée<br>Un serveur arrêté passe DOWN en moins de 5 s |
| 9 | role-A | **Passer à 4 serveurs applicatifs avec NB_APP=4 (R3)** - Démontrer que l'ajout de serveurs se fait en changeant une seule valeur. | `NB_APP=4 vagrant up` crée app3 et app4<br>HAProxy liste 4 serveurs sans intervention<br>V1 montre les 4 serveurs |
| 10 | role-A | **Reconstruction complète sur le poste d'un autre membre (semaine 2)** - `vagrant destroy -f` puis `vagrant up` sur un poste qui n'est pas le sien, pour débusquer les gestes manuels oubliés. | Reconstruction réussie sans aucune commande manuelle<br>Durée notée dans le journal de bord |
| 11 | role-B | **Comportement de l'application quand la base est absente** - Vérifier les 503 JSON propres et le retour automatique quand la base revient. | bdd1 arrêtée → /sante renvoie 503 JSON, jamais une page blanche<br>bdd1 relancée → /sante revient à 200 sans redémarrer l'application<br>Appui au rôle A sur HAProxy si besoin |
| 12 | role-C | **Réplication en flux bdd1 → bdd2 (R5)** - Vérifier que bdd2 est une réplique en flux et qu'une écriture sur bdd1 y est visible. | `SELECT pg_is_in_recovery()` = true sur bdd2<br>Insertion sur bdd1 lue sur bdd2 (commandes notées pour le dossier)<br>`pg_stat_replication` sur bdd1 montre bdd2 |
| 13 | role-C, rotation | **Rotation C : requête SQL de /resultat dans app/app.py** - Commit hors domaine du rôle C : relire et améliorer la requête de /resultat. | Requête paramétrée conservée (pas d'injection)<br>PR relue par le rôle B |
| 14 | role-D | **Scénario V1 : répartition** - Lancer tests/v1_repartition.sh et relever l'écart entre serveurs. | Sortie brute dans resultats/<br>Écart < 20 % ou explication |
| 15 | role-D | **Scénario V2 : panne d'un serveur applicatif** - Lancer tests/v2_panne_app.sh et relever requêtes perdues et durée dégradée. | Sortie brute dans resultats/<br>Aucune erreur au-delà de 5 s ou explication |
| 16 | role-D | **Idempotence : vagrant provision rejoué deux fois (R2)** - Lancer tests/idempotence.sh et corriger tout fichier qui change au second rejeu. | Le script affiche OK<br>Sortie brute dans resultats/ |

## J3 - V4 passe, E1 et E2 prêtes (19/10)

Bascule de la base, répartiteur redondant et supervision démontrés.

| N° | Rôle | Ticket | Critères de fin |
|---|---|---|---|
| 17 | role-C | **Procédure de bascule chronométrée sur bdd2 (R6, V4)** - Tester scripts/bascule.sh et le scénario tests/v4_panne_bdd.sh. | /sante renvoie 503 JSON pendant la panne<br>Service rétabli après la bascule, durée mesurée<br>Procédure rédigée pour le dossier |
| 18 | role-C | **Remise en service de bdd1 comme réplique de bdd2** - Après une bascule, bdd1 ne doit pas repartir en primaire. Écrire et tester la procédure de retour. | Procédure écrite (script ou étapes)<br>Limite documentée si non automatisée |
| 19 | role-B, rotation | **Rotation B : relecture et durcissement de scripts/bascule.sh** - Commit hors domaine du rôle B : gestion d'erreurs, messages clairs, aucun secret affiché. | PR relue par le rôle C |
| 20 | role-A, extension | **Extension E1 : lb2, keepalived et IP virtuelle (V6)** - Activer AVEC_LB2=1 et démontrer que le service reste joignable sur 192.168.60.10 quand lb1 tombe. | `vagrant halt lb1` : reprise en moins de 5 s<br>tests/v6_panne_lb.sh lancé, sortie dans resultats/ |
| 21 | role-D, rotation | **Rotation D : provisionnement de lb2 dans scripts/keepalived.sh** - Commit hors domaine du rôle D, en binôme avec le rôle A sur E1. | PR relue par le rôle A |
| 22 | role-D, extension | **Extension E2 : Prometheus, node_exporter et Grafana** - Activer AVEC_OBS=1, tester scripts/obs.sh et provisionner un tableau de bord sans clic manuel. | Tableau de bord JSON dans config/grafana/dashboards/<br>Débit visible pendant une charge, serveur qui disparaît pendant une panne<br>Captures d'écran pour le dossier |
| 23 | role-B | **Pare-feu ufw par rôle (R8)** - Tester scripts/parefeu.sh rôle par rôle, puis activer PAREFEU=1 par défaut si tout passe. | V1, V2, V4 et V6 passent avec le pare-feu actif<br>Seul lb1 expose un port vers l'hôte (Vagrantfile) |
| 24 | role-A, rotation | **Rotation A : script de charge tests/v3_charge.sh** - Commit hors domaine du rôle A : finaliser le script de montée en charge. | ab -n 2000 -c 50 exécuté<br>PR relue par le rôle D |

## Rendu - 25 octobre (25/10)

Mesures, dossier, journal de bord, démonstration répétée.

| N° | Rôle | Ticket | Critères de fin |
|---|---|---|---|
| 25 | role-D | **Campagne de mesures V1 à V6 (V3 avec N=2 puis N=4)** - Mesures finales, toutes produites par les scripts de tests/. Aucun chiffre inventé (−4 points). | Sorties brutes dans resultats/<br>Tableau de résultats et commentaires honnêtes pour le dossier |
| 26 | role-A | **Reconstruction finale sur un poste vierge (R1, V5)** - Répétition de la démonstration : clone neuf, `vagrant up`, chronométré. | Réussite sans intervention<br>Durée notée pour le dossier |
| 27 | role-B | **README testé par un lecteur neuf et historique sans secret (R7)** - Un membre suit le README sans aide ; `git log -p` ne contient aucun mot de passe. | README suivi de bout en bout sans question<br>Aucun secret dans l'historique |
| 28 | tous | **Rédiger sa section du dossier d'architecture (avant le 22 octobre)** - Chacun rédige les sections de son rôle dans docs/dossier_architecture.md. | Section A rédigée<br>Section B rédigée<br>Section C rédigée<br>Section D rédigée |
| 29 | role-B | **Compiler le dossier (10 à 15 pages) et le journal de bord** - Assembler, relire, mettre en forme et exporter en PDF. | Dossier complet et relu<br>Journal de bord 1 à 2 pages |
| 30 | tous | **Répétition de la démonstration avec tirage au sort** - Simuler la soutenance : destruction, reconstruction, trois scénarios tirés au sort, chacun présente une partie qu'il n'a pas écrite. | Démonstration tenue en 20 minutes<br>Chaque membre a présenté une partie d'un autre |
