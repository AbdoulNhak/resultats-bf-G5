# Dossier d'architecture — RÉSULTATS-BF (Groupe 5)

Livrable L2 — 10 à 15 pages. Compilé par le rôle B ; chaque section est rédigée
par le rôle indiqué. Remplacer les consignes en italique par le contenu.

## 1. Contexte et exigences (rôle B) — 1 page
*Le cas, les deux exigences non fonctionnelles (résilience, scalabilité), les
contraintes (Vagrant, 3 Go, sous-réseau 192.168.60.0/24, aucun coût).*

## 2. Architecture (rôle A) — 2 pages
*Schéma (lb, app, bdd, obs, flux), plan d'adressage, justification de chaque
choix : pourquoi HAProxy, pourquoi une sonde /sante qui interroge la base,
pourquoi la source unique de vérité noeuds.yml.*

## 3. Points de défaillance unique (rôles A et C) — 1 page
*Tableau : composant, ce qui se passe s'il tombe, comment on l'a supprimé
(ou pourquoi il reste : ex. bdd1 sans bascule automatique).*

## 4. Application sans état (rôle B) — 1 page
*Points d'entrée, absence d'état, connexion par requête, comportement quand la
base est absente, chaîne de connexion multi-hôtes.*

## 5. Données et réplication (rôle C) — 1,5 page
*Schéma de la table, génération des 50 000 lignes, réplication en flux,
vérification R5.*

## 6. Sécurité (rôle B) — 1 page
*Gestion des secrets (R7), cloisonnement réseau (R8), pare-feu, compte
applicatif en lecture seule, requêtes paramétrées.*

## 7. Procédures d'exploitation (rôles C et A) — 1,5 page
### 7.1 Bascule de la base sur bdd2 (R6)
*Commande, étapes, durée mesurée, retour arrière : remise en service de bdd1
comme réplique.*
### 7.2 Ajout d'un serveur applicatif (R3)
*NB_APP=4 vagrant up ; ce qui se passe ; vérification.*

## 8. Résultats des scénarios V1 à V6 (rôle D) — 3 pages
Pour chaque scénario : commande exacte, résultat brut (extrait de `resultats/`),
tableau de mesures, commentaire honnête.

| Scénario | Mesure | Valeur obtenue | Attendu | Commentaire |
|---|---|---|---|---|
| V1 | Écart entre serveurs | | < 20 % | |
| V2 | Requêtes perdues / période dégradée | | 0 au-delà de 5 s | |
| V3 | Requêtes/s avec N=2 et N=4 | | hausse | |
| V4 | Durée de la bascule | | | |
| V5 | Durée de reconstruction | | sans intervention | |
| V6 | Temps de reprise VRRP | | < 5 s | |

## 9. Extensions (rôles A et D) — 1 page
*E1 et E2 : ce qui a été fait, démonstration, captures d'écran Grafana.*

## 10. Limites connues et ce que nous ferions autrement (tous) — 1 page
*Ex. : bascule de base manuelle, pas de retour automatique de bdd1, CPU partagé
qui fausse les mesures de charge, pas de cache (E3)…*
