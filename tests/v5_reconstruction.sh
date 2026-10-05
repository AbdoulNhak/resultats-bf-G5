#!/usr/bin/env bash
# V5 — Reconstruction intégrale (R1) : vagrant destroy -f puis vagrant up.
# Attendu : plateforme fonctionnelle sans aucune intervention.
# Mesure : durée totale de la reconstruction.
set -euo pipefail
cd "$(dirname "$0")/.."
source tests/config.sh

{
  echo "V5 — Reconstruction — $(date '+%F %T')"
  t0=$(horodatage)
  vagrant destroy -f
  vagrant up
  t1=$(horodatage)
  echo "Durée de la reconstruction : $(duree "$t0" "$t1") s"
  echo "Contrôle : /sante = $(code_http "$URL/sante") ; /resultat = $(code_http "$URL/resultat?matricule=$MATRICULE")"
} 2>&1 | journaliser v5
