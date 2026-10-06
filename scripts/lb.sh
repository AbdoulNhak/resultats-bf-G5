#!/usr/bin/env bash
# lb1 / lb2 — répartiteur de charge HAProxy.
# Responsable : rôle A (architecte réseau et répartition)
# Exécuté à CHAQUE `vagrant up` (run: "always") pour suivre NB_APP (R3).
source /vagrant/scripts/lib.sh

installer_paquets haproxy python3-yaml

# Page d'erreur propre quand plus aucun serveur n'est sain (scénario V4)
tmp=$(mktemp)
printf 'HTTP/1.1 503 Service Unavailable\r\nContent-Type: application/json; charset=utf-8\r\nCache-Control: no-cache\r\nConnection: close\r\n\r\n{"statut":"indisponible","message":"Service momentanement indisponible, reessayez dans un instant."}\n' > "$tmp"
installer_fichier "$tmp" /etc/haproxy/errors/503-resultats.http || true

# Exporter Prometheus intégré, seulement si HAProxy a été compilé avec
OPTION=""
if [ "${AVEC_OBS:-0}" = "1" ] && haproxy -vv 2>/dev/null | grep -q PROMEX; then
  OPTION="--promex"
fi

# Configuration engendrée depuis la source unique de vérité
tmp=$(mktemp)
python3 /vagrant/scripts/generer_haproxy.py /vagrant/config/noeuds.yml "$MON_IP" $OPTION > "$tmp"
haproxy -c -q -f "$tmp" || { journal "ERREUR : configuration HAProxy invalide"; exit 1; }

systemctl enable --quiet haproxy
if installer_fichier "$tmp" /etc/haproxy/haproxy.cfg; then
  systemctl reload-or-restart haproxy
else
  systemctl start haproxy
fi

journal "HAProxy prêt : $(grep -c '^    server ' /etc/haproxy/haproxy.cfg) serveurs applicatifs"
