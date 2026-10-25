#!/usr/bin/env bash
# V4 - Panne de la base primaire, puis bascule sur bdd2.
# Attendu : /sante renvoie proprement 503 (JSON), jamais une page blanche ;
# puis la procédure de bascule rétablit le service.
# Mesure : temps total de la procédure de bascule.
set -euo pipefail
cd "$(dirname "$0")/.."
source tests/config.sh

etat_vagrant=$(vagrant status --machine-readable)
vm_active() {
  printf '%s\n' "$etat_vagrant" | awk -F, -v vm="$1" \
    '$2 == vm && $3 == "state" && $4 == "running" { active=1 } END { exit !active }'
}

for vm in bdd1 bdd2; do
  if ! vm_active "$vm"; then
    echo "ERREUR : $vm doit être démarrée avant le scénario V4." >&2
    exit 1
  fi
done

nb_apps=0
for vm in app1 app2 app3 app4 app5 app6 app7 app8 app9; do
  if vm_active "$vm"; then
    nb_apps=$((nb_apps + 1))
  fi
done
if [ "$nb_apps" -eq 0 ]; then
  echo "ERREUR : au moins un serveur applicatif doit être démarré avant V4." >&2
  exit 1
fi

if ! vm_active lb1 && ! vm_active lb2; then
  echo "ERREUR : au moins un répartiteur doit être démarré avant V4." >&2
  exit 1
fi

reponse=$(curl -sS -m 5 -w '\n%{http_code}\n%{content_type}' "$URL/sante") || {
  echo "ERREUR : le service ne répond pas avant la panne ; V4 est annulé." >&2
  exit 1
}
code=$(printf '%s\n' "$reponse" | tail -n 2 | head -n 1)
type=$(printf '%s\n' "$reponse" | tail -n 1)
corps=$(printf '%s\n' "$reponse" | sed '$d' | sed '$d')
if [ "$code" != "200" ] || [[ "$type" != application/json* ]] \
  || ! printf '%s\n' "$corps" | grep -Eq '"statut"[[:space:]]*:[[:space:]]*"ok"'; then
  echo "ERREUR : /sante doit répondre 200 JSON avant le scénario. Reçu : HTTP $code, $type, $corps" >&2
  exit 1
fi

{
  echo "V4 - Panne de bdd1 - $(date '+%F %T') - cible $URL"
  echo "Vérification initiale : /sante répond HTTP $code ($type)."
  t0=$(horodatage)
  vagrant halt -f bdd1
  echo "[$(date +%T)] bdd1 arrêtée"

  echo "Vérification de /sante pendant la panne :"
  reponse=$(curl -sS -m 5 -w '\n%{http_code}\n%{content_type}' "$URL/sante")
  code=$(printf '%s\n' "$reponse" | tail -n 2 | head -n 1)
  type=$(printf '%s\n' "$reponse" | tail -n 1)
  corps=$(printf '%s\n' "$reponse" | sed '$d' | sed '$d')
  printf '%s\n' "$corps"
  echo "HTTP $code ($type)"
  if [ "$code" != "503" ] || [[ "$type" != application/json* ]] \
    || ! printf '%s\n' "$corps" | grep -Eq '"statut"[[:space:]]*:[[:space:]]*"indisponible"'; then
    echo "ERREUR : pendant la panne, /sante doit répondre 503 JSON avec statut indisponible." >&2
    exit 1
  fi

  bash scripts/bascule.sh
  echo "Temps total depuis l'arrêt de bdd1 : $(duree "$t0" "$(horodatage)") s"

  reponse=$(curl -sS -m 5 -w '\n%{http_code}\n%{content_type}' "$URL/sante")
  code=$(printf '%s\n' "$reponse" | tail -n 2 | head -n 1)
  type=$(printf '%s\n' "$reponse" | tail -n 1)
  corps=$(printf '%s\n' "$reponse" | sed '$d' | sed '$d')
  if [ "$code" != "200" ] || [[ "$type" != application/json* ]] \
    || ! printf '%s\n' "$corps" | grep -Eq '"statut"[[:space:]]*:[[:space:]]*"ok"'; then
    echo "ERREUR : après la bascule, /sante doit répondre 200 JSON." >&2
    exit 1
  fi
  echo "Vérification après bascule : /sante répond HTTP 200 ($type)."

  echo "Vérification d'une lecture après bascule :"
  reponse=$(curl -sS -m 5 -w '\n%{http_code}\n%{content_type}' "$URL/resultat?matricule=$MATRICULE")
  code=$(printf '%s\n' "$reponse" | tail -n 2 | head -n 1)
  type=$(printf '%s\n' "$reponse" | tail -n 1)
  corps=$(printf '%s\n' "$reponse" | sed '$d' | sed '$d')
  printf '%s\n' "$corps"
  if [ "$code" != "200" ] || [[ "$type" != application/json* ]] \
    || ! printf '%s\n' "$corps" | grep -Fq "\"matricule\":\"$MATRICULE\""; then
    echo "ERREUR : la lecture du résultat échoue après la bascule." >&2
    exit 1
  fi
} | journaliser v4
