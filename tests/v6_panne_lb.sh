#!/usr/bin/env bash
# V6 - Panne du répartiteur actif (extension E1, AVEC_LB2=1).
# Attendu : le service reste joignable à la même adresse (IP virtuelle).
# Mesure : temps de reprise après bascule VRRP.
set -euo pipefail
cd "$(dirname "$0")/.."
source tests/config.sh

VIP_URL="http://${RESEAU}.10"
journal=$(mktemp)
t0=$(horodatage)
( sleep 3; echo "$(horodatage) PANNE" >> "$journal"; vagrant halt lb1 >/dev/null 2>&1 ) &

while [ "$(duree "$t0" "$(horodatage)" | cut -d. -f1)" -lt 40 ]; do
  echo "$(horodatage) $(code_http "$VIP_URL/info")" >> "$journal"
  sleep 0.2
done
wait

{
  echo "V6 - Panne de lb1 - $(date '+%F %T') - cible $VIP_URL"
  awk '/PANNE/ { tp = $1; next }
       { total++; if ($2 != "200") { ko++; if (!p) p = $1; d = $1 } }
       END { printf "Requêtes : %d ; en erreur : %d\n", total, ko
             if (ko) printf "Interruption : %.1f s (de %.1f s à %.1f s après la panne)\n", d - p, p - tp, d - tp
             else print "Aucune interruption mesurée." }' "$journal"
  echo "Pensez à relancer : vagrant up lb1"
} | journaliser v6
