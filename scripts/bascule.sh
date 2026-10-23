#!/usr/bin/env bash
# Procédure de bascule de la base : promotion de bdd2 en primaire (R6, scénario V4).
# Responsable : rôle C (ingénieur données) - relecture : rôle B (rotation)
#
# À lancer DEPUIS L'HÔTE, à la racine du dépôt (Linux, macOS ou Git Bash) :
#   bash scripts/bascule.sh
#
# Les serveurs applicatifs n'ont rien à changer : leur chaîne de connexion liste
# bdd1 puis bdd2 avec target_session_attrs=read-write ; dès que bdd2 accepte
# les écritures, ils l'utilisent.
#
# ATTENTION - après une bascule, NE PAS redémarrer bdd1 tel quel : il repartirait
# en primaire (deux primaires = « split brain »). Utiliser ensuite
# scripts/remise_en_service.sh pour le reconstruire comme réplique de bdd2.
set -euo pipefail
cd "$(dirname "$0")/.."
source tests/config.sh

debut=$(horodatage)
echo "[$(date +%T)] Bascule : promotion de bdd2"

etat=$(vagrant ssh bdd2 -c "sudo -u postgres psql -qtAc 'SELECT pg_is_in_recovery()'" 2>/dev/null | tr -d '[:space:]') || {
  echo "ERREUR : impossible de vérifier l'état de bdd2." >&2
  exit 1
}
case "$etat" in
  t)
    vagrant ssh bdd2 -c "sudo -u postgres psql -qtAc 'SELECT pg_promote(true, 30)'" 2>/dev/null
    ;;
  f)
    echo "bdd2 est déjà primaire : rien à promouvoir."
    ;;
  *)
    echo "ERREUR : état inattendu de bdd2 : '$etat'." >&2
    exit 1
    ;;
esac

echo "[$(date +%T)] Attente du retour de /sante à 200 via le répartiteur…"
delai_max=${DELAI_MAX_BASCULE:-60}
case "$delai_max" in
  ''|*[!0-9]*|0)
    echo "ERREUR : DELAI_MAX_BASCULE doit être un entier positif." >&2
    exit 1
    ;;
esac
debut_attente=$SECONDS
while [ "$(code_http "$URL/sante")" != "200" ]; do
  if (( SECONDS - debut_attente >= delai_max )); then
    echo "ERREUR : /sante n'est pas revenu à 200 après ${delai_max}s." >&2
    exit 1
  fi
  sleep 0.5
done

fin=$(horodatage)
echo "[$(date +%T)] Service rétabli. Durée de la procédure : $(duree "$debut" "$fin") s"
