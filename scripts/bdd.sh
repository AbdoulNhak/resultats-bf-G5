#!/usr/bin/env bash
# bdd1 - base de données primaire (lecture et écriture).
# Responsable : rôle C (ingénieur données)
source /vagrant/scripts/lib.sh
source /vagrant/scripts/pg_commun.sh

pg_configurer
attendre_port 127.0.0.1 5432 60

# Rôles : créés s'ils manquent, mot de passe (re)posé à chaque fois depuis .env
psql_su <<SQL
DO \$\$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'app') THEN
    CREATE ROLE app LOGIN;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'replicateur') THEN
    CREATE ROLE replicateur LOGIN REPLICATION;
  END IF;
END
\$\$;
ALTER ROLE app PASSWORD '${PG_APP_PASSWORD}';
ALTER ROLE replicateur PASSWORD '${PG_REPL_PASSWORD}';
SQL

# Base
if [ -z "$(psql_su -c "SELECT 1 FROM pg_database WHERE datname = 'resultats'")" ]; then
  sudo -u postgres createdb resultats
fi

# Schéma + 50 000 lignes (idempotent : IF NOT EXISTS / ON CONFLICT DO NOTHING)
sudo -u postgres psql -v ON_ERROR_STOP=1 -q -d resultats -f /vagrant/config/schema.sql

journal "bdd1 prête : $(psql_su -d resultats -c 'SELECT count(*) FROM resultats') lignes"
