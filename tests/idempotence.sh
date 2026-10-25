# #!/usr/bin/env bash
# # R2 - Idempotence : `vagrant provision` rejoué deux fois ne modifie rien et n'échoue pas.
# # Responsable : rôle D (essais)
# # Compare l'empreinte des fichiers de configuration de chaque VM entre deux rejeux.
# set -euo pipefail
# cd "$(dirname "$0")/.."
# source tests/config.sh

# FICHIERS="/etc/hosts /etc/haproxy/haproxy.cfg /etc/keepalived/keepalived.conf \
# /etc/postgresql/*/main/conf.d/resultats.conf /etc/postgresql/*/main/pg_hba.conf \
# /etc/systemd/system/resultats.service /etc/resultats-bf/app.env /opt/resultats-bf/app.py \
# /etc/prometheus/prometheus.yml"

# vms=$(vagrant status --machine-readable | awk -F, '$3 == "state" && $4 == "running" { print $2 }')

# empreintes() {
#   for vm in $vms; do
#     vagrant ssh "$vm" -c "sudo md5sum $FICHIERS 2>/dev/null; sudo -u postgres psql -d resultats -qtAc 'SELECT count(*) FROM resultats' 2>/dev/null" 2>/dev/null \
#       | sed "s/^/$vm /"
#   done
# }

# {
#   echo "R2 - Idempotence - $(date '+%F %T') - VM : $(echo $vms)"
#   vagrant provision >/dev/null
#   empreintes > /tmp/empreintes_1.txt
#   vagrant provision >/dev/null
#   empreintes > /tmp/empreintes_2.txt
#   if diff /tmp/empreintes_1.txt /tmp/empreintes_2.txt; then
#     echo "OK : aucun fichier modifié par le second rejeu ($(wc -l < /tmp/empreintes_1.txt) empreintes comparées)."
#   else
#     echo "ÉCHEC : des fichiers ont changé (voir les différences ci-dessus)."
#   fi
# } | journaliser idempotence


#!/usr/bin/env bash
# R2 - Idempotence : `vagrant provision` rejoué deux fois ne modifie rien et n'échoue pas.
# Responsable : rôle D (essais) - correction du 25/10 par le rôle A
# Compare l'empreinte des fichiers de configuration de chaque VM entre deux rejeux.
set -euo pipefail
cd "$(dirname "$0")/.."
source tests/config.sh

FICHIERS="/etc/hosts /etc/haproxy/haproxy.cfg /etc/keepalived/keepalived.conf \
/etc/postgresql/*/main/conf.d/resultats.conf /etc/postgresql/*/main/pg_hba.conf \
/etc/systemd/system/resultats.service /etc/resultats-bf/app.env /opt/resultats-bf/app.py \
/etc/prometheus/prometheus.yml"

vms=$(vagrant status --machine-readable | awk -F, '$3 == "state" && $4 == "running" { print $2 }')

# Les fichiers absents d'une VM (ex. haproxy.cfg sur bdd1) et le comptage SQL hors
# des VM de base échouent normalement : « ; true » et « || true » évitent que
# set -e n'arrête le script sans rapport.
empreintes() {
  for vm in $vms; do
    echo "  empreintes de $vm" >&2
    vagrant ssh "$vm" -c "sudo md5sum $FICHIERS 2>/dev/null; sudo -u postgres psql -d resultats -qtAc 'SELECT count(*) FROM resultats' 2>/dev/null; true" 2>/dev/null \
      | tr -d '\r' | sed "s/^/$vm /" || true
  done
}

rejouer() {
  echo "Rejeu $1 de vagrant provision (plusieurs minutes)" >&2
  if ! vagrant provision >/dev/null 2>&1; then
    echo "ÉCHEC : le rejeu $1 de vagrant provision a échoué (lancer « vagrant provision » pour voir l'erreur)."
    exit 1
  fi
}

{
  echo "R2 - Idempotence - $(date '+%F %T') - VM : $(echo $vms)"
  rejouer 1
  empreintes > /tmp/empreintes_1.txt
  rejouer 2
  empreintes > /tmp/empreintes_2.txt
  if diff /tmp/empreintes_1.txt /tmp/empreintes_2.txt; then
    echo "OK : aucun fichier modifié par le second rejeu ($(wc -l < /tmp/empreintes_1.txt) empreintes comparées)."
  else
    echo "ÉCHEC : des fichiers ont changé (voir les différences ci-dessus)."
  fi
} | journaliser idempotence