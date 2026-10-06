-- Schéma et jeu de données de RÉSULTATS-BF
-- Responsable : rôle C (ingénieur données)
-- Rejouable sans effet (R2) : IF NOT EXISTS et ON CONFLICT DO NOTHING.

CREATE TABLE IF NOT EXISTS resultats (
    matricule  varchar(12)   PRIMARY KEY,
    nom        varchar(80)   NOT NULL,
    serie      varchar(4)    NOT NULL,
    moyenne    numeric(4,2)  NOT NULL CHECK (moyenne BETWEEN 0 AND 20),
    admis      boolean       NOT NULL
);

-- Graine fixe : le jeu de données est identique sur tous les postes
SELECT setseed(0.42);

INSERT INTO resultats (matricule, nom, serie, moyenne, admis)
SELECT matricule, nom, serie, moyenne, moyenne >= 10
FROM (
    SELECT 'BF' || lpad(i::text, 6, '0')                              AS matricule,
           'Candidat ' || i                                           AS nom,
           (ARRAY['A4', 'C', 'D', 'E', 'F', 'G1', 'G2'])[1 + i % 7]   AS serie,
           round((random() * 20)::numeric, 2)                         AS moyenne
    FROM generate_series(1, 50000) AS i
) AS t
ON CONFLICT (matricule) DO NOTHING;

-- Le compte applicatif ne peut que lire
GRANT SELECT ON resultats TO app;
