#!/usr/bin/env bash
# Crée labels, jalons (milestones) et tickets (issues) du projet sur GitHub.
# Prérequis : GitHub CLI installé (https://cli.github.com) et `gh auth login` fait.
# À lancer depuis la racine du dépôt cloné (Git Bash sous Windows) :
#   bash outils/creer_tickets_github.sh
# Relançable sans risque : ce qui existe déjà est ignoré.
set -euo pipefail
cd "$(dirname "$0")/.."
command -v gh >/dev/null || { echo 'GitHub CLI (gh) introuvable : https://cli.github.com'; exit 1; }
gh auth status >/dev/null 2>&1 || { echo 'Lancez d abord : gh auth login'; exit 1; }

echo '== Labels'
gh label create role-A --color 1D76DB --description 'Réseau, répartition et intégration' --force >/dev/null && echo "  role-A"
gh label create role-B --color 0E8A16 --description 'Applicatif, sécurité et documentation' --force >/dev/null && echo "  role-B"
gh label create role-C --color FBCA04 --description 'Données' --force >/dev/null && echo "  role-C"
gh label create role-D --color D93F0B --description 'Essais et observabilité' --force >/dev/null && echo "  role-D"
gh label create tous --color 5319E7 --description 'Tâche de toute l'"'"'équipe' --force >/dev/null && echo "  tous"
gh label create rotation --color C5DEF5 --description 'Commit hors de son domaine (exigé par le sujet)' --force >/dev/null && echo "  rotation"
gh label create extension --color BFD4F2 --description 'Extensions E1 à E4' --force >/dev/null && echo "  extension"
gh label create bug --color B60205 --description 'Quelque chose ne marche pas' --force >/dev/null && echo "  bug"

echo '== Jalons (milestones)'
existants=$(gh api 'repos/{owner}/{repo}/milestones?state=all&per_page=100' --jq '.[].title')
if ! grep -Fxq 'J1 — vagrant up de bout en bout' <<< "$existants"; then gh api 'repos/{owner}/{repo}/milestones' -f title='J1 — vagrant up de bout en bout' -f due_on=2026-10-07T23:59:59Z -f description='Le socle (bdd1, bdd2, app1, app2, lb1) démarre sans geste manuel.' >/dev/null; echo '  créé : J1 — vagrant up de bout en bout'; else echo '  déjà là : J1 — vagrant up de bout en bout'; fi
if ! grep -Fxq 'J2 — V1 et V2 passent' <<< "$existants"; then gh api 'repos/{owner}/{repo}/milestones' -f title='J2 — V1 et V2 passent' -f due_on=2026-10-13T23:59:59Z -f description='Répartition et sonde de santé opérationnelles, réplication en place.' >/dev/null; echo '  créé : J2 — V1 et V2 passent'; else echo '  déjà là : J2 — V1 et V2 passent'; fi
if ! grep -Fxq 'J3 — V4 passe, E1 et E2 prêtes' <<< "$existants"; then gh api 'repos/{owner}/{repo}/milestones' -f title='J3 — V4 passe, E1 et E2 prêtes' -f due_on=2026-10-19T23:59:59Z -f description='Bascule de la base, répartiteur redondant et supervision démontrés.' >/dev/null; echo '  créé : J3 — V4 passe, E1 et E2 prêtes'; else echo '  déjà là : J3 — V4 passe, E1 et E2 prêtes'; fi
if ! grep -Fxq 'Rendu — 25 octobre' <<< "$existants"; then gh api 'repos/{owner}/{repo}/milestones' -f title='Rendu — 25 octobre' -f due_on=2026-10-25T23:59:59Z -f description='Mesures, dossier, journal de bord, démonstration répétée.' >/dev/null; echo '  créé : Rendu — 25 octobre'; else echo '  déjà là : Rendu — 25 octobre'; fi

echo '== Tickets (issues)'
deja=$(gh issue list --state all --limit 300 --json title --jq '.[].title')
ticket() {  # titre labels jalon corps
  if grep -Fxq "$1" <<< "$deja"; then echo "  déjà là : $1"; return; fi
  gh issue create --title "$1" --label "$2" --milestone "$3" --body "$4" >/dev/null
  echo "  créé : $1"
}
ticket 'Installer l'"'"'environnement et réussir vagrant up sur son poste' tous 'J1 — vagrant up de bout en bout' 'Chaque membre installe VirtualBox 7, Vagrant 2.4 et Git, ajoute la boîte partagée et démarre le socle.

### Critères de fin
- [ ] Virtualisation (VT-x/AMD-V) activée dans le BIOS, Hyper-V désactivé sous Windows
- [ ] `vagrant box list` affiche bento/ubuntu-24.04 à la version épinglée
- [ ] `vagrant up` réussi, `curl http://192.168.60.11/info` répond
- [ ] Chaque membre coche son nom en commentaire du ticket'
ticket 'Initialiser le dépôt GitHub et la protection de main' role-A 'J1 — vagrant up de bout en bout' 'Dépôt privé, squelette poussé, collaborateurs invités, labels, jalons, tableau Projects, règle de protection de main.

### Critères de fin
- [ ] Squelette poussé sur main avec .gitattributes et .gitignore
- [ ] Les 3 autres membres ont accepté l'"'"'invitation
- [ ] Ruleset : PR obligatoire avec 1 approbation, pas de force push
- [ ] Fusion « merge commit » seulement, suppression auto des branches'
ticket 'Vérifier et épingler la version de la boîte bento/ubuntu-24.04' role-A 'J1 — vagrant up de bout en bout' 'La version de l'"'"'annexe (202404.23.0) n'"'"'existe peut-être plus. Choisir une version disponible, l'"'"'épingler dans le Vagrantfile, partager le fichier .box sur clé USB.

### Critères de fin
- [ ] `vagrant box add bento/ubuntu-24.04 --box-version <version>` réussit
- [ ] VERSION mise à jour dans le Vagrantfile
- [ ] Fichier .box transmis aux autres membres'
ticket 'Premier vagrant up du socle et corrections' role-A 'J1 — vagrant up de bout en bout' 'Faire tourner le squelette sur VirtualBox pour la première fois et corriger tout ce qui bloque.

### Critères de fin
- [ ] Les 5 VM démarrent sans erreur ni commande manuelle
- [ ] `/info` alterne entre app1 et app2 via lb1
- [ ] Corrections poussées par PR, problèmes notés dans le journal de bord'
ticket 'Tester l'"'"'application : /info, /sante, /resultat' role-B 'J1 — vagrant up de bout en bout' 'Vérifier les trois points d'"'"'entrée sur app1 et app2, et comprendre chaque ligne de app/app.py.

### Critères de fin
- [ ] /resultat?matricule=BF000123 renvoie un JSON correct
- [ ] Matricule invalide → 400, inconnu → 404
- [ ] Service gunicorn actif et redémarré automatiquement (systemctl)'
ticket 'Vérifier bdd1 : schéma, 50 000 lignes et comptes' role-C 'J1 — vagrant up de bout en bout' 'Contrôler le jeu de données et les rôles PostgreSQL créés par scripts/bdd.sh.

### Critères de fin
- [ ] `SELECT count(*) FROM resultats` = 50 000
- [ ] Le rôle app ne peut que lire (SELECT)
- [ ] Données hors de /vagrant (piège n°3)'
ticket 'Schéma d'"'"'architecture pour le dossier' role-D 'J1 — vagrant up de bout en bout' 'Dessiner l'"'"'architecture cible (lb, app, bdd, obs, flux, adresses du groupe 5).

### Critères de fin
- [ ] Schéma exporté en PNG dans docs/
- [ ] Adresses 192.168.60.x et ports indiqués'
ticket 'Valider la configuration HAProxy engendrée et la sonde /sante (R4)' role-A 'J2 — V1 et V2 passent' 'Vérifier que la configuration vient bien de config/noeuds.yml et que la sonde écarte un serveur en moins de 5 s.

### Critères de fin
- [ ] Aucune adresse d'"'"'app écrite en dur
- [ ] Page de statistiques http://192.168.60.11:8404 consultée
- [ ] Un serveur arrêté passe DOWN en moins de 5 s'
ticket 'Passer à 4 serveurs applicatifs avec NB_APP=4 (R3)' role-A 'J2 — V1 et V2 passent' 'Démontrer que l'"'"'ajout de serveurs se fait en changeant une seule valeur.

### Critères de fin
- [ ] `NB_APP=4 vagrant up` crée app3 et app4
- [ ] HAProxy liste 4 serveurs sans intervention
- [ ] V1 montre les 4 serveurs'
ticket 'Reconstruction complète sur le poste d'"'"'un autre membre (semaine 2)' role-A 'J2 — V1 et V2 passent' '`vagrant destroy -f` puis `vagrant up` sur un poste qui n'"'"'est pas le sien, pour débusquer les gestes manuels oubliés.

### Critères de fin
- [ ] Reconstruction réussie sans aucune commande manuelle
- [ ] Durée notée dans le journal de bord'
ticket 'Comportement de l'"'"'application quand la base est absente' role-B 'J2 — V1 et V2 passent' 'Vérifier les 503 JSON propres et le retour automatique quand la base revient.

### Critères de fin
- [ ] bdd1 arrêtée → /sante renvoie 503 JSON, jamais une page blanche
- [ ] bdd1 relancée → /sante revient à 200 sans redémarrer l'"'"'application
- [ ] Appui au rôle A sur HAProxy si besoin'
ticket 'Réplication en flux bdd1 → bdd2 (R5)' role-C 'J2 — V1 et V2 passent' 'Vérifier que bdd2 est une réplique en flux et qu'"'"'une écriture sur bdd1 y est visible.

### Critères de fin
- [ ] `SELECT pg_is_in_recovery()` = true sur bdd2
- [ ] Insertion sur bdd1 lue sur bdd2 (commandes notées pour le dossier)
- [ ] `pg_stat_replication` sur bdd1 montre bdd2'
ticket 'Rotation C : requête SQL de /resultat dans app/app.py' role-C,rotation 'J2 — V1 et V2 passent' 'Commit hors domaine du rôle C : relire et améliorer la requête de /resultat.

### Critères de fin
- [ ] Requête paramétrée conservée (pas d'"'"'injection)
- [ ] PR relue par le rôle B'
ticket 'Scénario V1 : répartition' role-D 'J2 — V1 et V2 passent' 'Lancer tests/v1_repartition.sh et relever l'"'"'écart entre serveurs.

### Critères de fin
- [ ] Sortie brute dans resultats/
- [ ] Écart < 20 % ou explication'
ticket 'Scénario V2 : panne d'"'"'un serveur applicatif' role-D 'J2 — V1 et V2 passent' 'Lancer tests/v2_panne_app.sh et relever requêtes perdues et durée dégradée.

### Critères de fin
- [ ] Sortie brute dans resultats/
- [ ] Aucune erreur au-delà de 5 s ou explication'
ticket 'Idempotence : vagrant provision rejoué deux fois (R2)' role-D 'J2 — V1 et V2 passent' 'Lancer tests/idempotence.sh et corriger tout fichier qui change au second rejeu.

### Critères de fin
- [ ] Le script affiche OK
- [ ] Sortie brute dans resultats/'
ticket 'Procédure de bascule chronométrée sur bdd2 (R6, V4)' role-C 'J3 — V4 passe, E1 et E2 prêtes' 'Tester scripts/bascule.sh et le scénario tests/v4_panne_bdd.sh.

### Critères de fin
- [ ] /sante renvoie 503 JSON pendant la panne
- [ ] Service rétabli après la bascule, durée mesurée
- [ ] Procédure rédigée pour le dossier'
ticket 'Remise en service de bdd1 comme réplique de bdd2' role-C 'J3 — V4 passe, E1 et E2 prêtes' 'Après une bascule, bdd1 ne doit pas repartir en primaire. Écrire et tester la procédure de retour.

### Critères de fin
- [ ] Procédure écrite (script ou étapes)
- [ ] Limite documentée si non automatisée'
ticket 'Rotation B : relecture et durcissement de scripts/bascule.sh' role-B,rotation 'J3 — V4 passe, E1 et E2 prêtes' 'Commit hors domaine du rôle B : gestion d'"'"'erreurs, messages clairs, aucun secret affiché.

### Critères de fin
- [ ] PR relue par le rôle C'
ticket 'Extension E1 : lb2, keepalived et IP virtuelle (V6)' role-A,extension 'J3 — V4 passe, E1 et E2 prêtes' 'Activer AVEC_LB2=1 et démontrer que le service reste joignable sur 192.168.60.10 quand lb1 tombe.

### Critères de fin
- [ ] `vagrant halt lb1` : reprise en moins de 5 s
- [ ] tests/v6_panne_lb.sh lancé, sortie dans resultats/'
ticket 'Rotation D : provisionnement de lb2 dans scripts/keepalived.sh' role-D,rotation 'J3 — V4 passe, E1 et E2 prêtes' 'Commit hors domaine du rôle D, en binôme avec le rôle A sur E1.

### Critères de fin
- [ ] PR relue par le rôle A'
ticket 'Extension E2 : Prometheus, node_exporter et Grafana' role-D,extension 'J3 — V4 passe, E1 et E2 prêtes' 'Activer AVEC_OBS=1, tester scripts/obs.sh et provisionner un tableau de bord sans clic manuel.

### Critères de fin
- [ ] Tableau de bord JSON dans config/grafana/dashboards/
- [ ] Débit visible pendant une charge, serveur qui disparaît pendant une panne
- [ ] Captures d'"'"'écran pour le dossier'
ticket 'Pare-feu ufw par rôle (R8)' role-B 'J3 — V4 passe, E1 et E2 prêtes' 'Tester scripts/parefeu.sh rôle par rôle, puis activer PAREFEU=1 par défaut si tout passe.

### Critères de fin
- [ ] V1, V2, V4 et V6 passent avec le pare-feu actif
- [ ] Seul lb1 expose un port vers l'"'"'hôte (Vagrantfile)'
ticket 'Rotation A : script de charge tests/v3_charge.sh' role-A,rotation 'J3 — V4 passe, E1 et E2 prêtes' 'Commit hors domaine du rôle A : finaliser le script de montée en charge.

### Critères de fin
- [ ] ab -n 2000 -c 50 exécuté
- [ ] PR relue par le rôle D'
ticket 'Campagne de mesures V1 à V6 (V3 avec N=2 puis N=4)' role-D 'Rendu — 25 octobre' 'Mesures finales, toutes produites par les scripts de tests/. Aucun chiffre inventé (−4 points).

### Critères de fin
- [ ] Sorties brutes dans resultats/
- [ ] Tableau de résultats et commentaires honnêtes pour le dossier'
ticket 'Reconstruction finale sur un poste vierge (R1, V5)' role-A 'Rendu — 25 octobre' 'Répétition de la démonstration : clone neuf, `vagrant up`, chronométré.

### Critères de fin
- [ ] Réussite sans intervention
- [ ] Durée notée pour le dossier'
ticket 'README testé par un lecteur neuf et historique sans secret (R7)' role-B 'Rendu — 25 octobre' 'Un membre suit le README sans aide ; `git log -p` ne contient aucun mot de passe.

### Critères de fin
- [ ] README suivi de bout en bout sans question
- [ ] Aucun secret dans l'"'"'historique'
ticket 'Rédiger sa section du dossier d'"'"'architecture (avant le 22 octobre)' tous 'Rendu — 25 octobre' 'Chacun rédige les sections de son rôle dans docs/dossier_architecture.md.

### Critères de fin
- [ ] Section A rédigée
- [ ] Section B rédigée
- [ ] Section C rédigée
- [ ] Section D rédigée'
ticket 'Compiler le dossier (10 à 15 pages) et le journal de bord' role-B 'Rendu — 25 octobre' 'Assembler, relire, mettre en forme et exporter en PDF.

### Critères de fin
- [ ] Dossier complet et relu
- [ ] Journal de bord 1 à 2 pages'
ticket 'Répétition de la démonstration avec tirage au sort' tous 'Rendu — 25 octobre' 'Simuler la soutenance : destruction, reconstruction, trois scénarios tirés au sort, chacun présente une partie qu'"'"'il n'"'"'a pas écrite.

### Critères de fin
- [ ] Démonstration tenue en 20 minutes
- [ ] Chaque membre a présenté une partie d'"'"'un autre'

echo 'Terminé : 30 tickets. Assignez-les dans l onglet Issues ou le tableau Projects.'
