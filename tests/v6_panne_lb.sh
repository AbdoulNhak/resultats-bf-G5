#!/usr/bin/env bash
# V6 - Panne du répartiteur actif (extension E1, AVEC_LB2=1).
# Attendu : le service reste joignable à la même adresse (IP virtuelle).
# Mesure : temps de reprise après bascule VRRP.
set -euo pipefail
cd "$(dirname "$0")/.."
source tests/config.sh

VIP_URL="http://${RESEAU}.10"
RELANCER=${RELANCER:-1}
# Prérequis : E1 active (lb2 allumé) et IP virtuelle joignable avant la panne
if ! vagrant status lb2 2>/dev/null | grep -q 'running'; then
  echo "lb2 n'est pas démarré : activer E1 (AVEC_LB2=1 dans .env) puis vagrant up" >&2; exit 1
fi
if [ "$(code_http "$VIP_URL/info")" != "200" ]; then
  echo "L'IP virtuelle $VIP_URL ne répond pas avant la panne : mesure impossible" >&2; exit 1
fi

journal=$(mktemp)
t0=$(horodatage)
( sleep 3; echo "$(horodatage) PANNE" >> "$journal"; code=0; vagrant halt -f lb1 >/dev/null 2>&1 || code=$?; echo "$(horodatage) ARRET code=$code" >> "$journal" ) &
pid_arret=$!

while [ "$(duree "$t0" "$(horodatage)" | cut -d. -f1)" -lt 40 ]; do
  echo "$(horodatage) $(code_http "$VIP_URL/info")" >> "$journal"
  sleep 0.2
done
wait "$pid_arret" || true
code_arret=$(awk '$2 == "ARRET" { sub("code=", "", $3); print $3 }' "$journal")
code_arret=${code_arret:-0}

{
  echo "V6 - Panne de lb1 - $(date '+%F %T') - cible $VIP_URL"
  if [ "$code_arret" -ne 0 ]; then
    echo "ATTENTION : l'arrêt de lb1 a échoué (code $code_arret), mesure non valable"
  fi
  awk '/PANNE/ { tp = $1; next }
       $2 == "ARRET" { next }
       { total++; if ($2 != "200") { ko++; if (!p) p = $1; d = $1 } }
       END { printf "Requêtes : %d ; en erreur : %d\n", total, ko
             if (ko) printf "Interruption : %.1f s (de %.1f s à %.1f s après la panne)\n", d - p, p - tp, d - tp
             else print "Aucune interruption mesurée." }' "$journal"
   if [ "$RELANCER" = "1" ]; then
    t_relance=$(horodatage)
    vagrant up lb1 >/dev/null 2>&1 || echo "ATTENTION : vagrant up lb1 a échoué"
    revenu=0
    for ((seconde = 0; seconde < 60; seconde++)); do
      # lb1 répond de nouveau ET porte de nouveau l'IP virtuelle (préemption VRRP)
      if [ "$(code_http "http://${RESEAU}.11/info")" = "200" ] && \
         vagrant ssh lb1 -c "ip -o -4 addr show | grep -q ' ${RESEAU}.10/'" >/dev/null 2>&1; then
        echo "lb1 de retour et maître de l'IP virtuelle $(duree "$t_relance" "$(horodatage)") s après le lancement de vagrant up"
        revenu=1
        break
      fi
      sleep 1
    done
    [ "$revenu" -eq 1 ] || echo "lb1 n'a pas repris l'IP virtuelle après 60 s"
  fi
} | journaliser v6
