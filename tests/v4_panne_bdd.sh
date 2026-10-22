#!/usr/bin/env bash
# V4 - Panne de la base primaire, puis bascule sur bdd2.
# Attendu : /sante renvoie proprement 503 (JSON), jamais une page blanche ;
# puis la procédure de bascule rétablit le service.
# Mesure : temps total de la procédure de bascule.
set -euo pipefail
cd "$(dirname "$0")/.."
source tests/config.sh

{
  echo "V4 - Panne de bdd1 - $(date '+%F %T') - cible $URL"
  t0=$(horodatage)
  vagrant halt -f bdd1 >/dev/null 2>&1 || echo "ATTENTION : arrêt de bdd1 en échec"
  echo "[$(date +%T)] bdd1 arrêtée"

  echo "Réponse de /sante pendant la panne :"
  curl -s -m 3 -w '\n(code HTTP %{http_code})\n' "$URL/sante"

  bash scripts/bascule.sh
  echo "Temps total depuis l'arrêt de bdd1 : $(duree "$t0" "$(horodatage)") s"

  echo "Vérification d'une lecture après bascule :"
  curl -s -m 3 "$URL/resultat?matricule=$MATRICULE"; echo
} | journaliser v4
