#!/usr/bin/env bash
# V2 — Panne d'un serveur applicatif pendant une charge.
# Attendu : service disponible ; plus aucune erreur au-delà de 5 secondes.
# Mesures : requêtes perdues, durée de la période dégradée.
set -euo pipefail
cd "$(dirname "$0")/.."
source tests/config.sh

CIBLE=${CIBLE:-app1}
DUREE=${DUREE:-40}          # secondes d'observation
PANNE_A=${PANNE_A:-5}       # la panne est déclenchée après 5 s

journal=$(mktemp)
t0=$(horodatage)
( sleep "$PANNE_A"; echo "$(horodatage) PANNE vagrant halt $CIBLE" >> "$journal"; vagrant halt "$CIBLE" >/dev/null 2>&1 ) &

while [ "$(duree "$t0" "$(horodatage)" | cut -d. -f1)" -lt "$DUREE" ]; do
  echo "$(horodatage) $(code_http "$URL/resultat?matricule=$MATRICULE")" >> "$journal"
  sleep 0.1
done
wait

{
  echo "V2 — Panne de $CIBLE — $(date '+%F %T') — cible $URL"
  awk -v t0="$t0" '
    /PANNE/ { tp = $1; next }
    { total++; if ($2 != "200") { ko++; if (!premier) premier = $1; dernier = $1 } }
    END {
      printf "Requêtes envoyées : %d ; en erreur : %d (%.2f %%)\n", total, ko, ko / total * 100
      if (ko) printf "Période dégradée : de %.1f s à %.1f s après la panne (durée %.1f s)\n", premier - tp, dernier - tp, dernier - premier
      else    print  "Aucune requête perdue."
    }' "$journal"
  echo "Pensez à relancer le serveur : vagrant up $CIBLE"
} | journaliser v2
