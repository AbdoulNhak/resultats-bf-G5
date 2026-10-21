#!/usr/bin/env bash
# Fonctions partagées par tous les scripts de provisionnement.
# Responsable : rôle A (intégration)
#
# Règles d'idempotence (R2) :
#   - on n'ajoute jamais une ligne avec >> sans vérifier qu'elle est absente ;
#   - on écrit les fichiers de configuration en entier, puis on ne les remplace
#     que si leur contenu a changé (fonction installer_fichier).

set -euo pipefail
export DEBIAN_FRONTEND=noninteractive

journal() { echo "[$(hostname)] $*"; }

# apt-get update au plus une fois toutes les 6 heures (connexion lente)
apt_maj() {
  local tampon=/var/cache/resultats-bf-apt-update
  if [ ! -f "$tampon" ] || [ -n "$(find "$tampon" -mmin +360)" ]; then
    journal "apt-get update"
    apt-get update -qq
    touch "$tampon"
  fi
}

# Installe en UNE seule commande les paquets manquants
installer_paquets() {
  local manquants=()
  for p in "$@"; do
    dpkg -s "$p" >/dev/null 2>&1 || manquants+=("$p")
  done
  if [ ${#manquants[@]} -gt 0 ]; then
    journal "installation : ${manquants[*]}"
    apt_maj || true
    if apt-get install -y -qq --no-install-recommends "${manquants[@]}"; then
      return 0
    fi

    rm -f /var/cache/resultats-bf-apt-update
    apt_maj || true
    sleep 5
    if ! apt-get install -y -qq --no-install-recommends "${manquants[@]}"; then
      journal "ERREUR : installation impossible de ${manquants[*]} (réseau ou dépôt Ubuntu injoignable)"
      return 1
    fi
  fi
}

# installer_fichier <source temporaire> <destination> [mode] [propriétaire]
# Remplace la destination seulement si le contenu diffère.
# Retourne 0 si le fichier a changé, 1 sinon.
installer_fichier() {
  local src="$1" dst="$2" mode="${3:-644}" proprio="${4:-root:root}"
  if [ -f "$dst" ] && cmp -s "$src" "$dst"; then
    rm -f "$src"
    return 1
  fi
  install -D -m "$mode" -o "${proprio%%:*}" -g "${proprio##*:}" "$src" "$dst"
  rm -f "$src"
  journal "mis à jour : $dst"
  return 0
}

# ajouter_ligne <ligne> <fichier> : ajoute la ligne si elle est absente
ajouter_ligne() {
  grep -qxF -- "$1" "$2" 2>/dev/null || echo "$1" >> "$2"
}

# attendre_port <hôte> <port> <délai en secondes>
attendre_port() {
  local hote="$1" port="$2" delai="${3:-120}" t=0
  until (echo > "/dev/tcp/$hote/$port") 2>/dev/null; do
    sleep 2; t=$((t + 2))
    if [ "$t" -ge "$delai" ]; then
      journal "ERREUR : $hote:$port injoignable après ${delai}s"
      return 1
    fi
  done
}
