#!/usr/bin/env python3
"""Engendre /etc/haproxy/haproxy.cfg à partir de config/noeuds.yml (R3).

Responsable : rôle A (architecte réseau et répartition)

Aucune adresse n'est écrite en dur : la liste des serveurs applicatifs vient de
la même source de vérité que le Vagrantfile. Ajouter un serveur = NB_APP=4.

Usage : generer_haproxy.py <noeuds.yml> <ip_locale> [--promex]
"""
import sys

import yaml

fichier, ip_locale = sys.argv[1], sys.argv[2]
promex = "--promex" in sys.argv
topo = yaml.safe_load(open(fichier))
apps = [n for n in topo["noeuds"] if n["role"] == "app"]
if len(apps) < 2:
    sys.exit("ERREUR : moins de deux serveurs applicatifs dans noeuds.yml")

serveurs = "\n".join(f"    server {n['nom']} {n['ip']}:5000 check" for n in apps)

metriques = f"""
# Métriques pour Prometheus (extension E2)
frontend metriques
    bind {ip_locale}:8405
    http-request use-service prometheus-exporter if {{ path /metrics }}
""" if promex else ""

print(f"""# Fichier ENGENDRÉ par scripts/generer_haproxy.py — ne pas modifier à la main.
# Source : config/noeuds.yml ({len(apps)} serveurs applicatifs)

global
    log /dev/log local0
    maxconn 4096
    user haproxy
    group haproxy
    daemon

defaults
    mode http
    log global
    option httplog
    option dontlognull
    timeout connect 2s
    timeout client  30s
    timeout server  30s
    timeout check   4s   # /sante peut attendre 2 s le délai de connexion à bdd1 après une bascule
    retries 2
    option redispatch          # une requête vers un serveur tombé est rejouée ailleurs
    errorfile 503 /etc/haproxy/errors/503-resultats.http

frontend web
    bind *:80
    default_backend apps

backend apps
    balance roundrobin
    option httpchk GET /sante  # la sonde interroge la base (R4)
    http-check expect status 200
    # 2 échecs à 1 s d'intervalle : serveur écarté en ~2 s (< 5 s exigées)
    default-server inter 1s fall 2 rise 2
{serveurs}

listen statistiques
    bind {ip_locale}:8404      # réseau privé uniquement (R8)
    stats enable
    stats uri /
    stats refresh 5s
{metriques}""")
