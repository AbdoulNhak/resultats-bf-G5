#!/usr/bin/env bash
# Provisionnement commun à toutes les machines.
# Responsable : rôle A (intégration) - node_exporter : rôle D (E2)
source /vagrant/scripts/lib.sh

PAQUETS=(curl ca-certificates python3-yaml apache2-utils)
[ "${AVEC_OBS:-0}" = "1" ] && PAQUETS+=(prometheus-node-exporter)
installer_paquets "${PAQUETS[@]}"

# Fuseau horaire (horodatage cohérent des mesures)
if [ "$(timedatectl show -p Timezone --value)" != "Africa/Ouagadougou" ]; then
  timedatectl set-timezone Africa/Ouagadougou
fi

# /etc/hosts engendré depuis config/noeuds.yml (bloc délimité, réécrit en entier)
tmp=$(mktemp)
python3 - "$tmp" <<'PY'
import sys, yaml
topo = yaml.safe_load(open("/vagrant/config/noeuds.yml"))
lignes = [l for l in open("/etc/hosts").read().splitlines()]
# on retire l'ancien bloc géré
debut, fin = "# >>> resultats-bf", "# <<< resultats-bf"
garde, dedans = [], False
for l in lignes:
    if l == debut: dedans = True; continue
    if l == fin: dedans = False; continue
    if not dedans: garde.append(l)
bloc = [debut] + [f"{n['ip']}\t{n['nom']}" for n in topo["noeuds"]] + [fin]
open(sys.argv[1], "w").write("\n".join(garde + bloc) + "\n")
PY
installer_fichier "$tmp" /etc/hosts 644 || true

# Pare-feu (R8) - rôle B. Désactivé par défaut tant qu'il n'est pas testé.
if [ "${PAREFEU:-0}" = "1" ]; then
  bash /vagrant/scripts/parefeu.sh
fi

journal "socle commun OK"
