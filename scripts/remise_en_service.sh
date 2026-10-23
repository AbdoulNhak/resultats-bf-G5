#!/usr/bin/env bash
# Reconstruit bdd1 comme réplique de bdd2 après une bascule (R6).
# À lancer depuis l'hôte, à la racine du dépôt (Linux, macOS ou Git Bash).
set -euo pipefail
cd "$(dirname "$0")/.."

if [ ! -f .env ]; then
  echo "ERREUR : .env introuvable. Lancez d'abord vagrant up." >&2
  exit 1
fi

PG_REPL_PASSWORD=$(awk -F= '$1 == "PG_REPL_PASSWORD" { print substr($0, index($0, "=") + 1) }' .env | tr -d '\r')
if [ -z "$PG_REPL_PASSWORD" ]; then
  echo "ERREUR : PG_REPL_PASSWORD est absent de .env." >&2
  exit 1
fi

GROUPE_EFFECTIF=${GROUPE:-$(awk -F= '$1 == "GROUPE" { gsub(/\r/, "", $2); print $2; exit }' .env)}
GROUPE_EFFECTIF=${GROUPE_EFFECTIF:-5}
case "$GROUPE_EFFECTIF" in
  *[!0-9]*)
    echo "ERREUR : GROUPE doit être un entier." >&2
    exit 1
    ;;
esac
BDD2_IP="192.168.$((55 + GROUPE_EFFECTIF)).32"

etat=$(vagrant ssh bdd2 -c "sudo -u postgres psql -v ON_ERROR_STOP=1 -qtAc 'SELECT pg_is_in_recovery()'" 2>/dev/null | tr -d '[:space:]')
if [ "$etat" != "f" ]; then
  echo "ERREUR : bdd2 doit être démarrée et primaire avant la remise en service de bdd1." >&2
  exit 1
fi

read -r -p "Cette opération efface les données PostgreSQL de bdd1 et la recopie depuis bdd2. Tapez bdd1 pour confirmer : " confirmation
if [ "$confirmation" != "bdd1" ]; then
  echo "Opération annulée."
  exit 1
fi

echo "Arrêtez toute écriture applicative pendant la reconstruction."
echo "Si bdd1 est arrêtée, redémarrez-la sans reprovisionnement : vagrant up --no-provision bdd1"
read -r -p "Quand bdd1 est démarrée et accessible en SSH, appuyez sur Entrée pour continuer. "

vagrant ssh bdd1 -c "sudo bash -s" <<REMOTE
set -euo pipefail
BDD2_IP='${BDD2_IP}'
PG_REPL_PASSWORD='${PG_REPL_PASSWORD}'
PG_VER=\$(find /etc/postgresql -mindepth 1 -maxdepth 1 -type d -printf '%f\n' | sort -V | tail -1)
PG_DATA="/var/lib/postgresql/\$PG_VER/main"

systemctl stop postgresql
find "\$PG_DATA" -mindepth 1 -maxdepth 1 -exec rm -rf -- {} +
printf '%s:%s:replication:%s:%s\n' "\$BDD2_IP" 5432 replicateur "\$PG_REPL_PASSWORD" \
  | sudo -u postgres tee /var/lib/postgresql/.pgpass >/dev/null
chmod 600 /var/lib/postgresql/.pgpass
chown postgres:postgres /var/lib/postgresql/.pgpass
sudo -u postgres env PGPASSWORD="\$PG_REPL_PASSWORD" \
  pg_basebackup -h "\$BDD2_IP" -U replicateur -D "\$PG_DATA" -R -X stream
systemctl start postgresql
REMOTE

echo "Vérification de la réplication sur bdd1..."
etat=$(vagrant ssh bdd1 -c "sudo -u postgres psql -v ON_ERROR_STOP=1 -qtAc 'SELECT pg_is_in_recovery()'" 2>/dev/null | tr -d '[:space:]')
if [ "$etat" != "t" ]; then
  echo "ERREUR : bdd1 n'est pas en mode réplique." >&2
  exit 1
fi

flux=$(vagrant ssh bdd1 -c "sudo -u postgres psql -v ON_ERROR_STOP=1 -qtAc 'SELECT status FROM pg_stat_wal_receiver'" 2>/dev/null | tr -d '[:space:]')
if [ "$flux" != "streaming" ]; then
  echo "ERREUR : le flux WAL de bdd2 n'est pas actif (état : '$flux')." >&2
  exit 1
fi

echo "OK : bdd1 est réplique de bdd2 et le flux WAL est actif."
