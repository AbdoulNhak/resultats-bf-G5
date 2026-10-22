#!/usr/bin/env bash
# app1 … appN - serveurs applicatifs sans état.
# Responsable : rôle B (ingénieur applicatif et sécurité)
source /vagrant/scripts/lib.sh

installer_paquets python3-flask python3-psycopg2 gunicorn

# Compte système dédié, sans shell
id resultats >/dev/null 2>&1 || useradd --system --no-create-home --shell /usr/sbin/nologin resultats

# Code : copié depuis le dépôt (pas exécuté depuis /vagrant)
tmp=$(mktemp); cp /vagrant/app/app.py "$tmp"
installer_fichier "$tmp" /opt/resultats-bf/app.py 644 && REDEMARRER=1 || true

# Secrets : fichier lisible par root seul, chargé par systemd (R7)
tmp=$(mktemp)
cat > "$tmp" <<EOF
PG_HOSTS=${BDD1_IP},${BDD2_IP}
PG_DB=resultats
PG_USER=app
PG_APP_PASSWORD=${PG_APP_PASSWORD}
EOF
installer_fichier "$tmp" /etc/resultats-bf/app.env 600 && REDEMARRER=1 || true

# Service systemd : écoute sur 0.0.0.0 (piège n°1), redémarre tout seul
tmp=$(mktemp)
cat > "$tmp" <<'EOF'
[Unit]
Description=RÉSULTATS-BF - service applicatif
After=network-online.target
Wants=network-online.target

[Service]
User=resultats
EnvironmentFile=/etc/resultats-bf/app.env
WorkingDirectory=/opt/resultats-bf
ExecStart=/usr/bin/gunicorn --bind 0.0.0.0:5000 --workers 2 --threads 4 --access-logfile - app:app
Restart=always
RestartSec=2
NoNewPrivileges=true
ProtectSystem=strict
ProtectHome=true
PrivateTmp=true

[Install]
WantedBy=multi-user.target
EOF
if installer_fichier "$tmp" /etc/systemd/system/resultats.service; then
  systemctl daemon-reload
  REDEMARRER=1
fi

systemctl enable --quiet resultats
if [ "${REDEMARRER:-0}" = "1" ]; then
  systemctl restart resultats
else
  systemctl start resultats
fi

attendre_port 127.0.0.1 5000 30
journal "service applicatif prêt : $(curl -s localhost:5000/info)"
