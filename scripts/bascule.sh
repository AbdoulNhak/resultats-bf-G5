#!/usr/bin/env bash
# Procédure de bascule de la base : promotion de bdd2 en primaire (R6, scénario V4).
# Responsable : rôle C (ingénieur données) — relecture : rôle B (rotation)
#
# À lancer DEPUIS L'HÔTE, à la racine du dépôt (Linux, macOS ou Git Bash) :
#   bash scripts/bascule.sh
#
# Les serveurs applicatifs n'ont rien à changer : leur chaîne de connexion liste
# bdd1 puis bdd2 avec target_session_attrs=read-write ; dès que bdd2 accepte
# les écritures, ils l'utilisent.
#
# ATTENTION — après une bascule, NE PAS redémarrer bdd1 tel quel : il repartirait
# en primaire (deux primaires = « split brain »). Voir docs/ : remise en service
# de bdd1 comme réplique de bdd2 (TODO rôle C, à documenter dans le dossier).
set -euo pipefail
cd "$(dirname "$0")/.."
source tests/config.sh

debut=$(horodatage)
echo "[$(date +%T)] Bascule : promotion de bdd2"

etat=$(vagrant ssh bdd2 -c "sudo -u postgres psql -qtAc 'SELECT pg_is_in_recovery()'" 2>/dev/null | tr -d '[:space:]')
if [ "$etat" = "t" ]; then
  vagrant ssh bdd2 -c "sudo -u postgres psql -qtAc 'SELECT pg_promote(true, 30)'" 2>/dev/null
else
  echo "bdd2 est déjà primaire : rien à promouvoir."
fi

echo "[$(date +%T)] Attente du retour de /sante à 200 via le répartiteur…"
until [ "$(code_http "$URL/sante")" = "200" ]; do sleep 0.5; done

fin=$(horodatage)
echo "[$(date +%T)] Service rétabli. Durée de la procédure : $(duree "$debut" "$fin") s"
