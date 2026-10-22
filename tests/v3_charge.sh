#!/usr/bin/env bash
# V3 - Montée en charge : ab -n 2000 -c 50, répété 3 fois, avec N=2 puis N=4.
# Commit de rotation du rôle A.
#
#   bash tests/v3_charge.sh             # mesure avec la configuration actuelle
#   (NB_APP=4 dans .env) vagrant up     # passer à 4 serveurs
#   bash tests/v3_charge.sh             # nouvelle mesure
#   bash tests/v3_charge.sh --comparer  # tableau N=2 / N=4 à partir des dernières mesures
#
# Rappel du sujet : les VM partagent le processeur d'un seul poste ; le débit
# peut ne pas doubler, voire baisser. C'est un résultat à expliquer, pas un échec.
set -euo pipefail
cd "$(dirname "$0")/.."
source tests/config.sh

REPETITIONS=${REPETITIONS:-3}
REQUETES=${REQUETES:-2000}
CONCURRENCE=${CONCURRENCE:-50}

# Ligne de synthèse de la dernière mesure enregistrée pour N serveurs
derniere_synthese() {
  local f
  f=$(ls -1 resultats/v3_n"$1"_*.txt 2>/dev/null | sort | tail -1) || true
  [ -n "$f" ] && grep '^SYNTHESE' "$f" | tail -1
}

if [ "${1:-}" = "--comparer" ]; then
  echo "| Configuration | Essai 1 | Essai 2 | Essai 3 | Moyenne (req/s) | Requêtes en échec |"
  echo "|---|---|---|---|---|---|"
  for n in 2 3 4 5 6; do
    s=$(derniere_synthese "$n") || continue
    [ -n "$s" ] || continue
    # SYNTHESE n=<N> essais=<a;b;c> moyenne=<m> echecs=<e>
    echo "$s" | awk '{ for (i = 2; i <= NF; i++) { split($i, kv, "="); v[kv[1]] = kv[2] }
                       k = split(v["essais"], e, ";")
                       printf "| N = %s | %s | %s | %s | %s | %s |\n", v["n"], e[1], e[2], e[3], v["moyenne"], v["echecs"] }'
  done
  exit 0
fi

# Nombre de serveurs vus par HAProxy (page de statistiques de lb1, format CSV)
nb=$(curl -s -m 3 "http://${RESEAU}.11:8404/;csv" | grep -c '^apps,app' || true)
[ "${nb:-0}" -ge 1 ] || { echo "Statistiques HAProxy injoignables sur ${RESEAU}.11:8404" >&2; exit 1; }

# Échauffement : ouvre les connexions et remplit les caches avant de mesurer
lancer_ab -q -n 200 -c 10 "$URL/resultat?matricule=$MATRICULE" >/dev/null 2>&1 || true

brut=$(mktemp)
{
  echo "V3 - Charge - $(date '+%F %T') - $nb serveurs applicatifs - cible $URL"
  echo "ab -n $REQUETES -c $CONCURRENCE, $REPETITIONS essais"
  for r in $(seq 1 "$REPETITIONS"); do
    lancer_ab -q -n "$REQUETES" -c "$CONCURRENCE" "$URL/resultat?matricule=$MATRICULE" \
      | grep -E 'Requests per second|Failed requests|Non-2xx|Time per request.*mean\)' \
      | sed "s/^/essai $r : /" | tee -a "$brut"
  done
  # Synthèse calculée à partir des sorties brutes ci-dessus (rien n'est saisi à la main)
  awk -v n="$nb" '
    /Requests per second/ { essais = essais sep $7; sep = ";"; somme += $7; k++ }
    /Failed requests/     { f[$2] = $6 }
    /Non-2xx/             { x[$2] = $6 }
    # Une réponse 503 est comptée par ab dans « Failed » ET dans « Non-2xx » :
    # on retient, pour chaque essai, le plus grand des deux (pas leur somme).
    END { for (e in f) echecs += (x[e] > f[e] ? x[e] : f[e])
          printf "SYNTHESE n=%s essais=%s moyenne=%.1f echecs=%d\n", n, essais, (k ? somme / k : 0), echecs }' "$brut"
} | journaliser "v3_n${nb}"
rm -f "$brut"
