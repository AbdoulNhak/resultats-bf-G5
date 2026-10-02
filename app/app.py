"""RÉSULTATS-BF — service applicatif sans état.

Responsable : rôle B (ingénieur applicatif et sécurité)

Contraintes respectées :
  * aucun état local : ni session, ni fichier, ni compteur ; tout vit dans la base ;
  * une connexion par requête : l'application démarre même si la base est absente,
    et se reconnecte d'elle-même quand la base revient ;
  * bascule transparente : PG_HOSTS liste bdd1 puis bdd2, et libpq choisit le
    serveur qui accepte les écritures (target_session_attrs=read-write) ;
  * jamais de page blanche ni d'erreur brute : toute panne de base renvoie un 503 JSON.
"""
import os
import re
import socket

import psycopg2
from flask import Flask, jsonify, request

app = Flask(__name__)
HOTE = socket.gethostname()
MATRICULE_VALIDE = re.compile(r"^[A-Z]{2}[0-9]{6}$")

_hotes = os.environ["PG_HOSTS"].split(",")
DSN = (
    f"host={','.join(_hotes)} "
    f"port={','.join(['5432'] * len(_hotes))} "
    f"dbname={os.environ.get('PG_DB', 'resultats')} "
    f"user={os.environ.get('PG_USER', 'app')} "
    f"password={os.environ['PG_APP_PASSWORD']} "
    "target_session_attrs=read-write connect_timeout=2"
)


def requete(sql, params=()):
    """Exécute une requête de lecture et ferme la connexion aussitôt."""
    cnx = psycopg2.connect(DSN)
    try:
        with cnx.cursor() as cur:
            cur.execute(sql, params)
            return cur.fetchone()
    finally:
        cnx.close()  # « with cnx » ne ferme pas la connexion avec psycopg2


def indisponible(exc):
    app.logger.warning("base indisponible : %s", exc)
    return jsonify(statut="indisponible", serveur=HOTE,
                   message="Base de données injoignable, réessayez dans un instant."), 503


@app.get("/resultat")
def resultat():
    matricule = (request.args.get("matricule") or "").strip().upper()
    if not MATRICULE_VALIDE.match(matricule):
        return jsonify(erreur="matricule invalide (format attendu : BF000123)"), 400
    try:
        ligne = requete(
            "SELECT matricule, nom, serie, moyenne, admis FROM resultats WHERE matricule = %s",
            (matricule,),  # requête paramétrée : pas d'injection SQL
        )
    except psycopg2.Error as exc:
        return indisponible(exc)
    if ligne is None:
        return jsonify(erreur="matricule inconnu", matricule=matricule), 404
    m, nom, serie, moyenne, admis = ligne
    return jsonify(matricule=m, nom=nom, serie=serie,
                   moyenne=float(moyenne), admis=admis, serveur=HOTE)


@app.get("/sante")
def sante():
    # Interroge réellement la base : ne renvoie JAMAIS 200 par principe (R4).
    try:
        requete("SELECT 1")
    except psycopg2.Error as exc:
        return indisponible(exc)
    return jsonify(statut="ok", serveur=HOTE), 200


@app.get("/info")
def info():
    return jsonify(serveur=HOTE), 200


@app.errorhandler(404)
def introuvable(_):
    return jsonify(erreur="ressource inconnue"), 404


@app.errorhandler(500)
def erreur_interne(_):
    return jsonify(erreur="erreur interne", serveur=HOTE), 500
