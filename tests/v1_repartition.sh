#!/usr/bin/env bash
# V1 — Répartition : 20 appels successifs à /info.
# Attendu : les N serveurs apparaissent tour à tour ; écart max-min < 20 %.
set -euo pipefail
cd "$(dirname "$0")/.."
source tests/config.sh

{
  echo "V1 — Répartition — $(date '+%F %T') — cible $URL"
  for i in $(seq 1 20); do
    curl -s -m 2 "$URL/info" | sed -E 's/.*"serveur": ?"([^"]+)".*/\1/'
    echo
  done | grep -v '^$' | sort | uniq -c | tee /tmp/v1_comptes.txt
  awk '{ n[NR] = $1; t += $1 }
       END { mn = n[1]; mx = n[1]
             for (i in n) { if (n[i] < mn) mn = n[i]; if (n[i] > mx) mx = n[i] }
             printf "Total : %d appels sur %d serveurs ; plus sollicité %d, moins sollicité %d ; écart = %.0f %% de la moyenne\n",
                    t, NR, mx, mn, (mx - mn) / (t / NR) * 100 }' /tmp/v1_comptes.txt
} | journaliser v1
