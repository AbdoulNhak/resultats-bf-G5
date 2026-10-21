#!/usr/bin/env bash
# V3 - Montée en charge : ab -n 2000 -c 50, avec N=2 puis N=4.
# Commit de rotation prévu pour le rôle A.
#
#   bash tests/v3_charge.sh             # mesure avec la configuration actuelle
#   NB_APP=4 vagrant up                 # passer à 4 serveurs
#   bash tests/v3_charge.sh             # nouvelle mesure
#
# Rappel du sujet : les VM partagent le processeur d'un seul poste ; le débit
# peut ne pas doubler, voire baisser. C'est un résultat à expliquer, pas un échec.
set -euo pipefail
cd "$(dirname "$0")/.."
source tests/config.sh

REPETITIONS=${REPETITIONS:-3}
nb=$(curl -s "http://${RESEAU}.11:8404/;csv" | grep -c '^apps,app' || echo "?")

{
  echo "V3 - Charge - $(date '+%F %T') - $nb serveurs applicatifs - cible $URL"
  for r in $(seq 1 "$REPETITIONS"); do
    lancer_ab -q -n 2000 -c 50 "$URL/resultat?matricule=$MATRICULE" \
      | grep -E 'Requests per second|Failed requests|Non-2xx|Time per request.*mean\)' \
      | sed "s/^/essai $r : /"
  done
} | journaliser "v3_n${nb}"
