# -*- mode: ruby -*-
# vi: set ft=ruby :
#
# RÉSULTATS-BF - Groupe 5 - Infrastructure résiliente et scalable avec Vagrant
# Responsable : rôle A (architecte réseau et répartition)
#
# SOURCE UNIQUE DE VÉRITÉ : la table NOEUDS ci-dessous décrit les machines
# virtuelles ET alimente config/noeuds.yml, à partir duquel sont engendrées
# la configuration HAProxy, /etc/hosts et la configuration Prometheus.
# Aucune adresse de serveur applicatif n'est écrite en dur ailleurs (R3).
#
# Utilisation :
#   vagrant up                     # socle : bdd1, bdd2, app1, app2, lb1
#   NB_APP=4 vagrant up            # passer à 4 serveurs applicatifs (R3)
#   AVEC_LB2=1 vagrant up          # extension E1 (lb2 + IP virtuelle VRRP)
#   AVEC_OBS=1 vagrant up obs      # extension E2 (Prometheus + Grafana)
#
# Les valeurs NB_APP, AVEC_LB2 et AVEC_OBS peuvent aussi être fixées dans .env.

require 'yaml'
require 'fileutils'
require 'securerandom'

RACINE = File.dirname(__FILE__)

# ---------------------------------------------------------------------------
# 1. Secrets (R7) : lus dans .env, jamais versionné.
#    Sur un poste vierge, .env est créé automatiquement avec des mots de passe
#    aléatoires : aucun geste manuel n'est nécessaire (R1).
# ---------------------------------------------------------------------------
FICHIER_ENV = File.join(RACINE, ".env")
unless File.exist?(FICHIER_ENV)
  File.write(FICHIER_ENV, <<~ENV, encoding: "UTF-8")
    # Fichier engendré automatiquement par le Vagrantfile - NE PAS VERSIONNER.
    # Modèle documenté : .env.exemple
    PG_APP_PASSWORD=#{SecureRandom.hex(16)}
    PG_REPL_PASSWORD=#{SecureRandom.hex(16)}
    GRAFANA_ADMIN_PASSWORD=#{SecureRandom.hex(12)}
    KEEPALIVED_PASS=#{SecureRandom.hex(4)}
  ENV
  puts "==> .env absent : fichier créé avec des mots de passe aléatoires."
end

SECRETS = File.readlines(FICHIER_ENV, encoding: "UTF-8")
              .map(&:strip)
              .reject { |l| l.empty? || l.start_with?("#") }
              .map { |l| l.split("=", 2) }
              .to_h

def parametre(nom, defaut)
  ENV[nom] || SECRETS[nom] || defaut
end

# ---------------------------------------------------------------------------
# 2. Paramètres
# ---------------------------------------------------------------------------
GROUPE   = parametre("GROUPE", "5").to_i          # groupe 5 -> 192.168.60.0/24
NB_APP   = parametre("NB_APP", "2").to_i          # R3 : une seule valeur à changer
AVEC_LB2 = parametre("AVEC_LB2", "0") == "1"      # extension E1
AVEC_OBS = parametre("AVEC_OBS", "0") == "1"      # extension E2
PAREFEU  = parametre("PAREFEU", "0") == "1"       # R8 : pare-feu ufw (rôle B)
RESEAU   = "192.168.#{55 + GROUPE}"
BOITE    = "bento/ubuntu-24.04"
VERSION  = "202510.26.0"   # version épinglée pour tous (vérifiée : vagrant box add réussi)

abort "NB_APP doit être compris entre 2 et 9 (reçu : #{NB_APP})" unless (2..9).cover?(NB_APP)

# Garde-fou R3 : chaque commande Vagrant réécrit config/noeuds.yml. Si NB_APP=4
# n'a été donné que sur la ligne de commande, un simple `vagrant up lb1` ou
# `vagrant provision` ultérieur réengendrerait HAProxy avec 2 serveurs et
# app3/app4 deviendraient invisibles pour Vagrant. On prévient.
orphelins = Dir.glob(File.join(RACINE, ".vagrant", "machines", "app*", "*", "id"))
               .map { |f| File.basename(File.dirname(File.dirname(f))) }
               .select { |nom| nom.delete("app").to_i > NB_APP }
               .uniq.sort
if !orphelins.empty? && !$avertissement_affiche
  $avertissement_affiche = true
  warn "ATTENTION : #{orphelins.join(', ')} existe(nt) mais NB_APP=#{NB_APP}. " \
       "Fixez NB_APP dans .env (ex. NB_APP=#{orphelins.last.delete('app')}) " \
       "ou détruisez ces VM avant de réduire NB_APP."
end

# ---------------------------------------------------------------------------
# 3. Source unique de vérité
#    L'ordre compte : Vagrant démarre les machines dans cet ordre, donc la base
#    est prête avant les serveurs applicatifs, et ceux-ci avant le répartiteur.
# ---------------------------------------------------------------------------
NOEUDS = []
NOEUDS << { "nom" => "bdd1", "ip" => "#{RESEAU}.31", "mem" => 768, "role" => "bdd" }
NOEUDS << { "nom" => "bdd2", "ip" => "#{RESEAU}.32", "mem" => 768, "role" => "replique" }
(1..NB_APP).each do |i|
  NOEUDS << { "nom" => "app#{i}", "ip" => "#{RESEAU}.#{20 + i}", "mem" => 512, "role" => "app" }
end
NOEUDS << { "nom" => "lb1", "ip" => "#{RESEAU}.11", "mem" => 512, "role" => "lb", "priorite" => 150 }
LB2_IP = "#{RESEAU}.12"   # défini une seule fois : sert à lb2 et au pair VRRP de lb1
NOEUDS << { "nom" => "lb2", "ip" => LB2_IP, "mem" => 512, "role" => "lb", "priorite" => 100 } if AVEC_LB2
NOEUDS << { "nom" => "obs", "ip" => "#{RESEAU}.41", "mem" => 768, "role" => "obs" } if AVEC_OBS

TOPOLOGIE = {
  "groupe"   => GROUPE,
  "reseau"   => "#{RESEAU}.0/24",
  "vip"      => "#{RESEAU}.10",
  "avec_lb2" => AVEC_LB2,
  "avec_obs" => AVEC_OBS,
  "noeuds"   => NOEUDS,
}

FileUtils.mkdir_p(File.join(RACINE, "config"))
File.write(File.join(RACINE, "config", "noeuds.yml"), TOPOLOGIE.to_yaml)

def ip_de(nom)
  NOEUDS.find { |n| n["nom"] == nom }&.fetch("ip")
end

# ---------------------------------------------------------------------------
# Ports SSH sûrs sous Windows (R1) : Hyper-V, WSL et Docker réservent au
# démarrage des plages de ports aléatoires (netsh ... excludedportrange). Si la
# redirection SSH de Vagrant (2222, 2200...) tombe dedans, VirtualBox ne peut pas
# l'ouvrir et `vagrant up` attend jusqu'au délai maximal. On lit ces plages et
# on donne à chaque VM un port SSH libre, à partir de 2722.
# ---------------------------------------------------------------------------
def ports_exclus_windows
  return [] unless Gem.win_platform?
  sortie = `netsh interface ipv4 show excludedportrange protocol=tcp 2>NUL`
  sortie.to_s.b.scan(/^\s*(\d+)\s+(\d+)/n).map { |a, b| (a.to_i..b.to_i) }
rescue StandardError
  []
end
PORTS_EXCLUS = ports_exclus_windows
PORTS_PRIS = []
def port_ssh_libre(depart)
  port = depart
  port += 1 while PORTS_EXCLUS.any? { |r| r.cover?(port) } || PORTS_PRIS.include?(port)
  PORTS_PRIS << port
  port
end
if PORTS_EXCLUS.any? { |r| r.cover?(8080) } && !$avertissement_8080
  $avertissement_8080 = true
  warn "ATTENTION : Windows a réservé le port 8080 ; utilisez http://192.168.60.11 au lieu de localhost:8080, ou lancez en administrateur : net stop winnat, vagrant up, net start winnat."
end

# Variables passées à tous les scripts de provisionnement
ENV_COMMUN = SECRETS.merge(
  "GROUPE"   => GROUPE.to_s,
  "RESEAU"   => RESEAU,
  "SOUS_RESEAU" => "#{RESEAU}.0/24",
  "VIP"      => "#{RESEAU}.10",
  "BDD1_IP"  => ip_de("bdd1"),
  "BDD2_IP"  => ip_de("bdd2"),
  "LB1_IP"   => ip_de("lb1"),
  "LB2_IP"   => LB2_IP,
  "AVEC_LB2" => AVEC_LB2 ? "1" : "0",
  "AVEC_OBS" => AVEC_OBS ? "1" : "0",
  "PAREFEU"  => PAREFEU ? "1" : "0",
)

# ---------------------------------------------------------------------------
# 4. Machines virtuelles
# ---------------------------------------------------------------------------
Vagrant.configure("2") do |config|
  config.vm.box = BOITE
  config.vm.box_version = VERSION
  config.vm.box_check_update = false

  NOEUDS.each do |n|
    config.vm.define n["nom"] do |m|
      m.vm.hostname = n["nom"]
      m.vm.network "private_network", ip: n["ip"]
      # Redirection SSH sur un port que Windows n'a pas réservé (voir plus haut)
      m.vm.network "forwarded_port", id: "ssh", guest: 22, host: port_ssh_libre(2722),
                   host_ip: "127.0.0.1", auto_correct: true

      # R8 : seul le répartiteur actif expose un port vers l'hôte.
      if n["nom"] == "lb1"
        m.vm.network "forwarded_port", guest: 80, host: 8080, host_ip: "127.0.0.1"
      end

      m.vm.provider "virtualbox" do |vb|
        vb.name   = "resultats-bf-g#{GROUPE}-#{n['nom']}"
        vb.memory = n["mem"]
        vb.cpus   = 1
        vb.linked_clone = true
        # La VM résout les noms par le résolveur de l'hôte : le DNS reste valide si le PC change de réseau (Wi-Fi, veille, VPN).
        vb.customize ["modifyvm", :id, "--natdnshostresolver1", "on"]
      end

      env = ENV_COMMUN.merge("MON_NOM" => n["nom"], "MON_IP" => n["ip"], "ROLE" => n["role"])
      env["PRIORITE"] = n["priorite"].to_s if n["priorite"]

      # Socle commun : paquets, /etc/hosts, fuseau horaire, node_exporter (E2).
      # run: "always" : /etc/hosts suit NB_APP et node_exporter est installé
      # même si E2 est activée après coup. Le script est idempotent (R2).
      m.vm.provision "commun", type: "shell", path: "scripts/commun.sh", env: env, run: "always"

      case n["role"]
      when "lb"
        # run: "always" : la configuration HAProxy est réengendrée à chaque
        # `vagrant up`, pour suivre automatiquement NB_APP (R3).
        m.vm.provision "lb", type: "shell", path: "scripts/lb.sh", env: env, run: "always"
        # run: "always" : si E1 est activée sur une plateforme déjà construite,
        # lb1 (déjà provisionné) reçoit quand même keepalived.
        m.vm.provision "keepalived", type: "shell", path: "scripts/keepalived.sh", env: env, run: "always" if AVEC_LB2
      when "obs"
        # run: "always" : les cibles Prometheus suivent NB_APP (R3).
        m.vm.provision "obs", type: "shell", path: "scripts/obs.sh", env: env, run: "always"
      else
        m.vm.provision n["role"], type: "shell", path: "scripts/#{n['role']}.sh", env: env
      end
    end
  end
end
