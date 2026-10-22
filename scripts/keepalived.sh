#!/usr/bin/env bash
# Extension E1 - IP virtuelle partagée entre lb1 et lb2 (VRRP, keepalived).
# Responsable : rôle A, avec le rôle D (commit de rotation)
# Activée par AVEC_LB2=1. Démonstration : `vagrant halt lb1` (scénario V6).
source /vagrant/scripts/lib.sh

installer_paquets keepalived

# Interface portant l'adresse privée (ne pas supposer eth1)
IFACE=$(ip -o -4 addr show | awk -v ip="$MON_IP" '$4 ~ "^"ip"/" {print $2; exit}')
[ -n "$IFACE" ] || { journal "ERREUR : interface de $MON_IP introuvable"; exit 1; }

# Pair : l'autre répartiteur. Unicast plutôt que multicast (plus sûr sous VirtualBox).
if [ "$MON_IP" = "$LB1_IP" ]; then PAIR="$LB2_IP"; else PAIR="$LB1_IP"; fi

tmp=$(mktemp)
cat > "$tmp" <<EOF
# Géré par /vagrant/scripts/keepalived.sh - ne pas modifier à la main
global_defs {
    router_id ${MON_NOM}
    script_user root
    enable_script_security
}

vrrp_script verifier_haproxy {
    # script "/usr/bin/pidof haproxy"
    script "/usr/bin/systemctl is-active --quiet haproxy"
    interval 1
    fall 2
    rise 2
}

vrrp_instance VI_RESULTATS {
    state BACKUP
    interface ${IFACE}
    virtual_router_id $((50 + GROUPE))
    priority ${PRIORITE}
    advert_int 1
    unicast_src_ip ${MON_IP}
    unicast_peer {
        ${PAIR}
    }
    authentication {
        auth_type PASS
        auth_pass ${KEEPALIVED_PASS:0:8}
    }
    virtual_ipaddress {
        ${VIP}/24 dev ${IFACE}
    }
    track_script {
        verifier_haproxy
    }
}
EOF
installer_fichier "$tmp" /etc/keepalived/keepalived.conf 600 && systemctl restart keepalived || true
systemctl enable --quiet --now keepalived

journal "keepalived prêt (priorité ${PRIORITE}, VIP ${VIP})"
