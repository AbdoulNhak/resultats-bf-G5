# RÉSULTATS-BF — Groupe 5

Plateforme de consultation des résultats d'examen, résiliente et scalable,
entièrement décrite en code avec Vagrant et VirtualBox.
Master 1 Informatique — Virtualisation et Cloud Computing — Dr SOMDA — IBAM, 2026-2027.

> Rendu : **25 octobre 2026**. Sous-réseau du groupe 5 : **192.168.60.0/24**.

## 1. Prérequis

| Outil | Version testée | Remarque |
|---|---|---|
| VirtualBox | 7.x | Réseau hôte-seul 192.168.56.0/21 autorisé par défaut |
| Vagrant | 2.4.x | Version compatible avec votre VirtualBox |
| Git | 2.x | Sous Windows : Git Bash pour lancer les scripts de test |
| Mémoire libre | 3 Go (socle) | 8 Go de RAM sur le poste conseillés |

Aucun compte cloud, aucune ressource payante.

## 2. Démarrage en trois commandes

```bash
git clone <url-du-depot> resultats-bf
cd resultats-bf
vagrant up
```

Au premier `vagrant up` :

- la boîte `bento/ubuntu-24.04` est téléchargée une seule fois (environ 1 Go), puis gardée en cache ;
- le fichier `.env` est créé automatiquement avec des mots de passe aléatoires (voir `.env.exemple`).

Aucune autre action n'est nécessaire. Comptez 15 à 30 minutes pour la première construction.

Vérification :

```bash
curl http://192.168.60.11/sante                         # {"statut":"ok", ...}
curl "http://192.168.60.11/resultat?matricule=BF000123"
curl http://192.168.60.11/info                          # nom du serveur qui répond
curl http://localhost:8080/info                         # même service via la redirection de port
```

## 3. Architecture

![Architecture de RÉSULTATS-BF](docs/architecture.png)

| Machine | Adresse | RAM | Rôle |
|---|---|---|---|
| lb1 | 192.168.60.11 | 512 Mo | HAProxy actif — seul port exposé vers l'hôte (8080) |
| lb2 | 192.168.60.12 | 512 Mo | HAProxy passif, IP virtuelle 192.168.60.10 (E1) |
| app1 … appN | 192.168.60.21 … | 512 Mo | Service Python sans état (Flask + gunicorn, port 5000) |
| bdd1 | 192.168.60.31 | 768 Mo | PostgreSQL primaire |
| bdd2 | 192.168.60.32 | 768 Mo | PostgreSQL réplique en flux, promouvable |
| obs | 192.168.60.41 | 768 Mo | Prometheus + Grafana (E2) |

**Source unique de vérité** : la table `NOEUDS` du `Vagrantfile` engendre
`config/noeuds.yml`, d'où sont produits la configuration HAProxy
(`scripts/generer_haproxy.py`), `/etc/hosts` et les cibles Prometheus.
Aucune adresse de serveur applicatif n'est écrite en dur.

## 4. Opérations courantes

| Action | Commande |
|---|---|
| Passer à 4 serveurs applicatifs (R3) | `NB_APP=4 vagrant up` (ou `NB_APP=4` dans `.env`) |
| Activer le répartiteur redondant (E1) | `AVEC_LB2=1 vagrant up` |
| Activer la supervision (E2) | `AVEC_OBS=1 vagrant up` puis http://192.168.60.41:3000 |
| Rejouer le provisionnement (R2) | `vagrant provision` |
| Bascule de la base sur bdd2 (R6) | `bash scripts/bascule.sh` |
| Tout reconstruire (R1) | `vagrant destroy -f && vagrant up` |

> Pendant le développement, n'allumez pas tout en même temps : socle d'abord,
> puis une extension à la fois.

## 5. Scénarios de validation

Depuis la racine du dépôt (Linux, macOS ou Git Bash). Chaque script enregistre
sa sortie brute dans `resultats/`.

| Scénario | Commande |
|---|---|
| V1 Répartition | `bash tests/v1_repartition.sh` |
| V2 Panne d'un serveur applicatif | `bash tests/v2_panne_app.sh` |
| V3 Montée en charge (N=2 puis N=4) | `bash tests/v3_charge.sh` |
| V4 Panne de la base primaire | `bash tests/v4_panne_bdd.sh` |
| V5 Reconstruction | `bash tests/v5_reconstruction.sh` |
| V6 Panne du répartiteur (E1) | `bash tests/v6_panne_lb.sh` |
| R2 Idempotence | `bash tests/idempotence.sh` |

## 6. Arborescence

```
Vagrantfile              source unique de vérité (rôle A)
.env.exemple             modèle des secrets ; .env n'est jamais versionné (rôle B)
app/app.py               service HTTP sans état (rôle B)
config/schema.sql        table resultats + 50 000 lignes (rôle C)
config/grafana/          tableaux de bord provisionnés (rôle D)
scripts/commun.sh        socle commun à toutes les VM (rôle A)
scripts/lib.sh           fonctions d'idempotence (rôle A)
scripts/bdd.sh           PostgreSQL primaire (rôle C)
scripts/replique.sh      réplique en flux (rôle C)
scripts/bascule.sh       procédure de bascule chronométrée (rôle C)
scripts/app.sh           déploiement du service (rôle B)
scripts/lb.sh            HAProxy (rôle A)
scripts/generer_haproxy.py  configuration HAProxy engendrée (rôle A)
scripts/keepalived.sh    IP virtuelle VRRP, E1 (rôle A)
scripts/obs.sh           Prometheus + Grafana, E2 (rôle D)
scripts/parefeu.sh       pare-feu ufw, R8 (rôle B)
tests/                   scénarios V1 à V6 et idempotence (rôle D)
docs/                    dossier d'architecture et journal de bord (rôle B)
resultats/               sorties brutes des scénarios
```

## 7. Dépannage

- **Un service ne répond pas depuis une autre VM** : vérifier qu'il écoute sur
  `0.0.0.0` ou sur l'IP privée, jamais seulement sur `127.0.0.1`.
- **`/bin/bash^M: bad interpreter`** : fins de ligne Windows ; `.gitattributes`
  force LF, refaire un `git clone` propre.
- **HAProxy ne voit pas les nouveaux serveurs** : `vagrant provision lb1`.
- **Après une bascule** : ne pas redémarrer `bdd1` tel quel (il repartirait en
  primaire). Voir la procédure de remise en service dans le dossier.

## 8. Contribuer

1. Prendre un ticket dans l'onglet **Issues** et s'y assigner.
2. Créer une branche depuis `main` à jour :
   ```bash
   git switch main && git pull
   git switch -c 12-courte-description
   ```
3. Commiter en citant le ticket : `git commit -m "Sonde /sante dans HAProxy (#12)"`.
4. Pousser (`git push -u origin 12-courte-description`) et ouvrir une **pull request**
   vers `main` avec `Closes #12` dans la description.
5. Un membre d'un **autre rôle** relit, lance `vagrant up`, puis approuve.
6. Fusion par « Create a merge commit ».

Règles : jamais de `.env` dans un commit, jamais d'adresse de serveur applicatif en dur,
jamais de données PostgreSQL dans `/vagrant`.

## 9. Documentation

| Document | Contenu |
|---|---|
| [docs/dossier_architecture.md](docs/dossier_architecture.md) | Dossier d'architecture (livrable L2) |
| [docs/journal_de_bord.md](docs/journal_de_bord.md) | Journal de bord (livrable L3) |
| [docs/tickets.md](docs/tickets.md) | Liste des tickets par jalon |

## 10. Équipe

| Rôle | Membre |
|---|---|
| A — Architecte réseau, répartition et intégration | … |
| B — Ingénieur applicatif, sécurité et documentation | … |
| C — Ingénieur données | … |
| D — Essais et observabilité | … |
