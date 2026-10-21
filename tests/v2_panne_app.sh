#!/usr/bin/env bash
# V2 - Panne d'un serveur applicatif pendant une charge.
# Attendu : service disponible ; plus aucune erreur au-delà de 5 secondes.
# Mesures : requêtes perdues, durée de la période dégradée.
set -euo pipefail
cd "$(dirname "$0")/.."
source tests/config.sh

CIBLE=${CIBLE:-app1}
DUREE=${DUREE:-40}          # secondes d'observation
PANNE_A=${PANNE_A:-5}       # la panne est déclenchée après 5 s
RELANCER=${RELANCER:-1}

journal=$(mktemp)
t0=$(horodatage)
( sleep "$PANNE_A"; echo "$(horodatage) PANNE vagrant halt -f $CIBLE" >> "$journal"; code=0; vagrant halt -f "$CIBLE" >/dev/null 2>&1 || code=$?; echo "$(horodatage) ARRET code=$code" >> "$journal" ) &
pid_arret=$!

while [ "$(duree "$t0" "$(horodatage)" | cut -d. -f1)" -lt "$DUREE" ]; do
  echo "$(horodatage) $(code_http "$URL/resultat?matricule=$MATRICULE")" >> "$journal"
  sleep 0.1
done
wait "$pid_arret" || true
code_arret=$(awk '$2 == "ARRET" { sub("code=", "", $3); print $3 }' "$journal")
code_arret=${code_arret:-0}

{
  echo "V2 - Panne de $CIBLE - $(date '+%F %T') - cible $URL"
  if [ "$code_arret" -ne 0 ]; then
    echo "ATTENTION : l'arrêt de $CIBLE a échoué (code $code_arret), mesure non valable"
  fi
  awk -v t0="$t0" '
    $2 == "PANNE" { tp = $1; next }
    $2 == "ARRET" { next }
    { total++; if ($2 != "200") { ko++; if (!premier) premier = $1; dernier = $1 } }
    END {
      taux = total ? ko / total * 100 : 0
      printf "Requêtes envoyées : %d ; en erreur : %d (%.2f %%)\n", total, ko, taux
      if (ko) printf "Période dégradée : de %.1f s à %.1f s après la panne (durée %.1f s)\n", premier - tp, dernier - tp, dernier - premier
      else    print  "Aucune requête perdue."
    }' "$journal"
  if [ "$RELANCER" = "1" ]; then
    t_relance=$(horodatage)
    vagrant up "$CIBLE" >/dev/null 2>&1 || true
    revenu=0
    for ((seconde = 0; seconde < 60; seconde++)); do
      info=$(curl -s -m 0.2 "$URL/info" || true)
      if [[ "$info" == *"$CIBLE"* ]]; then
        echo "$CIBLE de retour dans la répartition $(duree "$t_relance" "$(horodatage)") s après le lancement de vagrant up"
        revenu=1
        break
      fi
      sleep 0.8
    done
    if [ "$revenu" -eq 0 ]; then
      echo "$CIBLE non revenu après 60 s"
    fi
  fi
} | journaliser v2
