#!/usr/bin/env bash
# Vérifications du rôle C : schéma, comptes, réplication et route SQL.
set -euo pipefail
cd "$(dirname "$0")/.."
source tests/config.sh

requete() {
  local vm=$1
  local sql=$2
  vagrant ssh "$vm" -c "sudo -u postgres psql -v ON_ERROR_STOP=1 -qtAc \"$sql\"" 2>/dev/null | tr -d '[:space:]'
}

verifier() {
  local description=$1
  local valeur=$2
  local attendu=$3
  if [ "$valeur" != "$attendu" ]; then
    echo "ÉCHEC : $description (attendu : $attendu ; obtenu : $valeur)." >&2
    exit 1
  fi
  echo "OK : $description ($valeur)"
}

echo "Vérification de bdd1..."
verifier "nombre de résultats dans bdd1" "$(requete bdd1 'SELECT count(*) FROM resultats')" 50000
verifier "nombre de colonnes du schéma resultats" \
  "$(requete bdd1 "SELECT count(*) FROM information_schema.columns WHERE table_schema = 'public' AND table_name = 'resultats'")" 5
verifier "compte applicatif présent" "$(requete bdd1 "SELECT count(*) FROM pg_roles WHERE rolname = 'app' AND rolcanlogin")" 1
verifier "compte de réplication présent" "$(requete bdd1 "SELECT count(*) FROM pg_roles WHERE rolname = 'replicateur' AND rolcanlogin AND rolreplication")" 1

echo "Vérification de bdd2..."
verifier "bdd2 en mode réplique" "$(requete bdd2 'SELECT pg_is_in_recovery()')" t
verifier "flux WAL actif sur bdd2" "$(requete bdd2 'SELECT status FROM pg_stat_wal_receiver')" streaming
verifier "nombre de résultats répliqués" "$(requete bdd2 'SELECT count(*) FROM resultats')" 50000

echo "Vérification de la route /resultat..."
code=$(curl -sS -o /dev/null -m 5 -w '%{http_code}' "$URL/resultat?matricule=$MATRICULE")
verifier "réponse pour le matricule de test" "$code" 200
code=$(curl -sS -o /dev/null -m 5 -w '%{http_code}' "$URL/resultat?matricule=INVALIDE")
verifier "rejet du matricule invalide" "$code" 400
code=$(curl -sS -o /dev/null -m 5 -w '%{http_code}' \
  "$URL/resultat?matricule=BF000123%27%20OR%20%271%27%3D%271")
verifier "rejet d'une entrée SQL malformée" "$code" 400

echo "Toutes les vérifications du rôle C ont réussi."
