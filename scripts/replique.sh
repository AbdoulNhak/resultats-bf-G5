#!/usr/bin/env bash
# bdd2 - réplique en flux de bdd1, promouvable (R5).
# Responsable : rôle C (ingénieur données)
source /vagrant/scripts/lib.sh
source /vagrant/scripts/pg_commun.sh

pg_configurer

MARQUEUR=/var/lib/postgresql/.resultats-replique-initialisee

# La copie initiale n'est faite qu'UNE fois. Sans ce marqueur, un
# `vagrant provision` après une bascule effacerait la base promue.
if [ ! -f "$MARQUEUR" ]; then
  journal "attente de bdd1 (${BDD1_IP}:5432)"
  attendre_port "$BDD1_IP" 5432 180

  journal "copie initiale depuis bdd1 (pg_basebackup)"
  systemctl stop postgresql
  rm -rf "${PG_DATA:?}"/*
  sudo -u postgres env PGPASSWORD="$PG_REPL_PASSWORD" \
    pg_basebackup -h "$BDD1_IP" -U replicateur -D "$PG_DATA" -R -X stream
  # -R écrit standby.signal + primary_conninfo : bdd2 démarre en réplique
  systemctl start postgresql
  touch "$MARQUEUR"
fi

attendre_port 127.0.0.1 5432 60
etat=$(psql_su -c "SELECT CASE WHEN pg_is_in_recovery() THEN 'réplique' ELSE 'primaire' END")
journal "bdd2 prête (état : $etat)"
