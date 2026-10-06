#!/usr/bin/env bash
# Configuration PostgreSQL commune à bdd1 et bdd2.
# Responsable : rôle C (ingénieur données)
# Sourcé par bdd.sh et replique.sh.

installer_paquets postgresql postgresql-contrib

PG_VER=$(ls /etc/postgresql | sort -V | tail -1)
PG_CONF_DIR=/etc/postgresql/$PG_VER/main
PG_DATA=/var/lib/postgresql/$PG_VER/main     # JAMAIS dans /vagrant (piège n°3)
export PG_VER PG_CONF_DIR PG_DATA

pg_configurer() {
  local change=1

  # Paramètres : fichier entier dans conf.d (inclus par défaut sous Ubuntu)
  local tmp; tmp=$(mktemp)
  cat > "$tmp" <<EOF
# Géré par /vagrant/scripts/pg_commun.sh — ne pas modifier à la main
listen_addresses = 'localhost,${MON_IP}'   # réseau privé uniquement (R8)
wal_level = replica
max_wal_senders = 5
wal_keep_size = '256MB'
hot_standby = on
max_connections = 100
EOF
  installer_fichier "$tmp" "$PG_CONF_DIR/conf.d/resultats.conf" 644 postgres:postgres && change=0

  # Accès : application et réplication, depuis le sous-réseau privé seulement
  local hba="$PG_CONF_DIR/pg_hba.conf"
  local avant; avant=$(md5sum "$hba")
  ajouter_ligne "host  resultats    app          ${SOUS_RESEAU}  scram-sha-256" "$hba"
  ajouter_ligne "host  replication  replicateur  ${BDD1_IP}/32   scram-sha-256" "$hba"
  ajouter_ligne "host  replication  replicateur  ${BDD2_IP}/32   scram-sha-256" "$hba"
  [ "$avant" != "$(md5sum "$hba")" ] && change=0

  systemctl enable --quiet postgresql
  if [ "$change" -eq 0 ]; then
    journal "configuration PostgreSQL modifiée : redémarrage"
    systemctl restart postgresql
  else
    systemctl start postgresql
  fi
}

psql_su() { sudo -u postgres psql -v ON_ERROR_STOP=1 -qtA "$@"; }
