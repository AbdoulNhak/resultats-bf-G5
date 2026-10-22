#!/usr/bin/env bash
# Extension E2 - supervision : Prometheus + Grafana sur la machine obs.
# Responsable : rôle D (essais et observabilité)
# Activée par AVEC_OBS=1. Grafana : http://192.168.60.41:3000 (admin / GRAFANA_ADMIN_PASSWORD du .env)
#
# TODO rôle D :
#   - tester ce script de bout en bout (dépôt Grafana, connexion lente) ;
#   - exporter le tableau de bord final en JSON dans config/grafana/dashboards/
#     (aucun import à la main : il doit apparaître tout seul après vagrant up).
source /vagrant/scripts/lib.sh

# Dépôt officiel Grafana (absent des dépôts Ubuntu)
if [ ! -f /etc/apt/sources.list.d/grafana.list ]; then
  installer_paquets gpg
  install -d -m 755 /etc/apt/keyrings
  curl -fsSL https://apt.grafana.com/gpg.key | gpg --dearmor -o /etc/apt/keyrings/grafana.gpg
  echo "deb [signed-by=/etc/apt/keyrings/grafana.gpg] https://apt.grafana.com stable main" \
    > /etc/apt/sources.list.d/grafana.list
  rm -f /var/cache/resultats-bf-apt-update   # forcer un apt-get update
fi
installer_paquets prometheus grafana

# Cibles Prometheus engendrées depuis noeuds.yml (aucune adresse en dur)
tmp=$(mktemp)
python3 - > "$tmp" <<'PY'
import yaml
topo = yaml.safe_load(open("/vagrant/config/noeuds.yml"))
noeuds = [n for n in topo["noeuds"]]
lbs = [n for n in noeuds if n["role"] == "lb"]
print("# ENGENDRÉ par scripts/obs.sh depuis config/noeuds.yml")
print("global:\n  scrape_interval: 5s\n  evaluation_interval: 5s\n")
print("scrape_configs:")
print("  - job_name: noeuds")
print("    static_configs:")
print("      - targets: [" + ", ".join(f"'{n['ip']}:9100'" for n in noeuds) + "]")
print("  - job_name: haproxy")
print("    static_configs:")
print("      - targets: [" + ", ".join(f"'{n['ip']}:8405'" for n in lbs) + "]")
PY
installer_fichier "$tmp" /etc/prometheus/prometheus.yml && systemctl restart prometheus || true

# Source de données et tableaux de bord provisionnés (pas de clic dans l'interface)
tmp=$(mktemp)
cat > "$tmp" <<'EOF'
apiVersion: 1
datasources:
  - name: Prometheus
    type: prometheus
    url: http://localhost:9090
    isDefault: true
EOF
installer_fichier "$tmp" /etc/grafana/provisioning/datasources/resultats.yml 644 root:grafana && G=1 || true

tmp=$(mktemp)
cat > "$tmp" <<'EOF'
apiVersion: 1
providers:
  - name: resultats-bf
    folder: RÉSULTATS-BF
    type: file
    options:
      path: /vagrant/config/grafana/dashboards
EOF
installer_fichier "$tmp" /etc/grafana/provisioning/dashboards/resultats.yml 644 root:grafana && G=1 || true

systemctl enable --quiet prometheus grafana-server
if [ "${G:-0}" = "1" ]; then systemctl restart grafana-server; else systemctl start grafana-server; fi

attendre_port 127.0.0.1 3000 90
grafana-cli admin reset-admin-password "$GRAFANA_ADMIN_PASSWORD" >/dev/null 2>&1 || true

journal "supervision prête : Grafana http://${MON_IP}:3000"
