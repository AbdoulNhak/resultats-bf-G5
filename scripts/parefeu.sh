#!/usr/bin/env bash
# Pare-feu ufw par rôle (R8 : tout le trafic interne passe par le réseau privé).
# Responsable : rôle B (sécurité)
# Désactivé par défaut. Pour l'activer : PAREFEU=1 dans .env, puis vagrant provision.
#
# TODO rôle B : tester rôle par rôle (V1 à V6 doivent toujours passer) avant
# d'activer PAREFEU=1 par défaut. Un pare-feu mal réglé casse R1 (note plafonnée).
source /vagrant/scripts/lib.sh

installer_paquets ufw

ufw default deny incoming  >/dev/null
ufw default allow outgoing >/dev/null
ufw allow 22/tcp >/dev/null                      # vagrant ssh (interface NAT)

autoriser() { ufw allow from "$SOUS_RESEAU" to any port "$1" proto tcp >/dev/null; }

case "$ROLE" in
  bdd|replique) autoriser 5432 ;;
  app)          autoriser 5000 ;;
  lb)           ufw allow 80/tcp >/dev/null      # redirection de port depuis l'hôte
                autoriser 8404; autoriser 8405
                ufw allow from "$SOUS_RESEAU" to any proto vrrp >/dev/null 2>&1 \
                  || ufw allow from "$SOUS_RESEAU" >/dev/null   # VRRP (protocole 112)
                ;;
  obs)          autoriser 3000; autoriser 9090 ;;
esac
[ "${AVEC_OBS:-0}" = "1" ] && autoriser 9100     # node_exporter

ufw --force enable >/dev/null
journal "pare-feu actif pour le rôle $ROLE"
