#!/usr/bin/env bash
# Paramètres et fonctions communs aux scénarios de validation.
# Responsable : rôle D (essais et observabilité)
# Scripts à lancer DEPUIS L'HÔTE, à la racine du dépôt (Linux, macOS ou Git Bash).

GROUPE=${GROUPE:-5}
RESEAU="192.168.$((55 + GROUPE))"

# Avec l'extension E1, on vise l'IP virtuelle ; sinon lb1 directement.
if grep -qs '^AVEC_LB2=1' .env || [ "${AVEC_LB2:-0}" = "1" ]; then
  URL=${URL:-"http://${RESEAU}.10"}
else
  URL=${URL:-"http://${RESEAU}.11"}
fi
MATRICULE=${MATRICULE:-BF000123}

mkdir -p resultats

horodatage() { date +%s.%N; }
duree() { awk -v a="$1" -v b="$2" 'BEGIN { printf "%.1f", b - a }'; }
code_http() { curl -s -o /dev/null -m 2 -w '%{http_code}' "$1" || true; }

# Exécute ab depuis l'hôte s'il est installé, sinon depuis bdd2 (apache2-utils
# y est installé par commun.sh). À préciser dans le dossier : où tourne le client.
lancer_ab() {
  if command -v ab >/dev/null 2>&1; then
    ab "$@"
  else
    echo "(ab absent sur l'hôte : exécution depuis bdd2)" >&2
    vagrant ssh bdd2 -c "ab $*" 2>/dev/null
  fi
}

# Enregistre la sortie d'un scénario dans resultats/<nom>_<date>.txt
journaliser() { tee "resultats/$1_$(date +%Y%m%d_%H%M%S).txt"; }
