-- ÉTAPE 1 : CRÉATION DE L'ENTREPÔT DE DONNÉES (DATA WAREHOUSE)

CREATE DATABASE IF NOT EXISTS avito_bi_dw 
CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

USE avito_bi_dw;


-- ÉTAPE 2 : COUCHE D'INGESTION (STAGING AREA) & IMPORTATION DE LA DONNÉE

CREATE TABLE IF NOT EXISTS staging_avito (
    Lien VARCHAR(500),
    Ville VARCHAR(100),
    Secteur VARCHAR(150),
    Marque VARCHAR(100),
    Modele VARCHAR(150),
    Annee_Modele INT,
    Kilometrage VARCHAR(100),
    Type_Carburant VARCHAR(50),
    Puissance_Fiscale INT,
    Boite_Vitesses VARCHAR(50),
    Nombre_Portes INT,
    Origine VARCHAR(100),
    Premiere_Main VARCHAR(50),
    Etat VARCHAR(50),
    Airbags INT,
    Climatisation INT,
    ABS INT,
    ESP INT,
    CD_MP3_Bluetooth INT,
    Prix DECIMAL(12, 2),
    ID_Annonce VARCHAR(50),
    Km_Min DECIMAL(12, 2),
    Km_Max DECIMAL(12, 2),
    Km_Moyen DECIMAL(12, 2),
    Nb_Equipements INT,
    Age_Vehicule INT
);


SELECT COUNT(*) AS Total_Annonces_Importees FROM staging_avito;

-- ÉTAPE 3 : TRAITEMENT ET STANDARDISATION EN SQL (IN-DATABASE TRANSFORMATION)

SET SQL_SAFE_UPDATES = 0;

UPDATE staging_avito
SET 
    Ville          = TRIM(Ville),
    Secteur        = COALESCE(NULLIF(TRIM(Secteur), ''), 'Non spécifié'),
    Marque         = UPPER(TRIM(Marque)),
    Modele         = TRIM(Modele),
    Type_Carburant = TRIM(Type_Carburant),
    Boite_Vitesses = CASE 
                        WHEN TRIM(Boite_Vitesses) IN ('--', '') THEN 'Non spécifié'
                        ELSE TRIM(Boite_Vitesses)
                     END,
    Origine        = COALESCE(NULLIF(TRIM(Origine), ''), 'Non spécifié'),
    Premiere_Main  = COALESCE(NULLIF(TRIM(Premiere_Main), ''), 'Non spécifié'),
    Etat           = COALESCE(NULLIF(TRIM(Etat), ''), 'Non spécifié');

SET SQL_SAFE_UPDATES = 1;

-- ÉTAPE 4 : ARCHITECTURE DU SCHÉMA EN ÉTOILE (DDL - STAR SCHEMA)

CREATE TABLE IF NOT EXISTS Dim_Localisation (
    id_localisation INT AUTO_INCREMENT PRIMARY KEY,
    ville VARCHAR(100) NOT NULL,
    secteur VARCHAR(150) NOT NULL,
    UNIQUE KEY uk_localisation (ville, secteur)
);

CREATE TABLE IF NOT EXISTS Dim_Vehicule (
    id_vehicule INT AUTO_INCREMENT PRIMARY KEY,
    marque VARCHAR(100) NOT NULL,
    modele VARCHAR(150) NOT NULL,
    annee_modele INT NOT NULL,
    age_vehicule INT NOT NULL,
    type_carburant VARCHAR(50) NOT NULL,
    puissance_fiscale INT NOT NULL,
    boite_vitesses VARCHAR(50) NOT NULL,
    nombre_portes INT NOT NULL,
    UNIQUE KEY uk_vehicule (marque, modele, annee_modele, type_carburant, puissance_fiscale, boite_vitesses, nombre_portes)
);

CREATE TABLE IF NOT EXISTS Dim_Condition (
    id_condition INT AUTO_INCREMENT PRIMARY KEY,
    origine VARCHAR(100) NOT NULL,
    premiere_main VARCHAR(50) NOT NULL,
    etat VARCHAR(50) NOT NULL,
    UNIQUE KEY uk_condition (origine, premiere_main, etat)
);

CREATE TABLE IF NOT EXISTS Fact_Annonces (
    id_fact INT AUTO_INCREMENT PRIMARY KEY,
    id_annonce VARCHAR(50),
    lien VARCHAR(500) NOT NULL,
    id_localisation INT NOT NULL,
    id_vehicule INT NOT NULL,
    id_condition INT NOT NULL,
    tranche_kilometrage VARCHAR(100),
    km_min DECIMAL(12, 2),
    km_max DECIMAL(12, 2),
    km_moyen DECIMAL(12, 2) NOT NULL,
    prix DECIMAL(12, 2) NOT NULL,
    airbags TINYINT(1) NOT NULL,
    climatisation TINYINT(1) NOT NULL,
    abs_equip TINYINT(1) NOT NULL,
    esp_equip TINYINT(1) NOT NULL,
    cd_mp3_bluetooth TINYINT(1) NOT NULL,
    nb_equipements INT NOT NULL,
    INDEX idx_fact_prix (prix),
    INDEX idx_fact_km (km_moyen),
    CONSTRAINT fk_fact_loc FOREIGN KEY (id_localisation) REFERENCES Dim_Localisation(id_localisation),
    CONSTRAINT fk_fact_veh FOREIGN KEY (id_vehicule) REFERENCES Dim_Vehicule(id_vehicule),
    CONSTRAINT fk_fact_cond FOREIGN KEY (id_condition) REFERENCES Dim_Condition(id_condition)
);

-- ÉTAPE 5 : ALIMENTATION DU SCHÉMA EN ÉTOILE (DML - NORMALISATION)

TRUNCATE TABLE Fact_Annonces;

INSERT IGNORE INTO Dim_Localisation (ville, secteur)
SELECT DISTINCT Ville, Secteur
FROM staging_avito;

INSERT IGNORE INTO Dim_Vehicule (marque, modele, annee_modele, age_vehicule, type_carburant, puissance_fiscale, boite_vitesses, nombre_portes)
SELECT DISTINCT 
    Marque, Modele, Annee_Modele, Age_Vehicule,
    Type_Carburant, Puissance_Fiscale, Boite_Vitesses, Nombre_Portes
FROM staging_avito;

INSERT IGNORE INTO Dim_Condition (origine, premiere_main, etat)
SELECT DISTINCT Origine, Premiere_Main, Etat
FROM staging_avito;

INSERT INTO Fact_Annonces (
    id_annonce, lien, id_localisation, id_vehicule, id_condition,
    tranche_kilometrage, km_min, km_max, km_moyen, prix,
    airbags, climatisation, abs_equip, esp_equip, cd_mp3_bluetooth, nb_equipements
)
SELECT 
    s.ID_Annonce,
    s.Lien,
    l.id_localisation,
    v.id_vehicule,
    c.id_condition,
    s.Kilometrage,
    s.Km_Min,
    s.Km_Max,
    s.Km_Moyen,
    s.Prix,
    s.Airbags,
    s.Climatisation,
    s.ABS,
    s.ESP,
    s.CD_MP3_Bluetooth,
    s.Nb_Equipements
FROM staging_avito s
INNER JOIN Dim_Localisation l 
    ON s.Ville = l.ville AND s.Secteur = l.secteur
INNER JOIN Dim_Vehicule v 
    ON s.Marque = v.marque 
    AND s.Modele = v.modele 
    AND s.Annee_Modele = v.annee_modele
    AND s.Type_Carburant = v.type_carburant
    AND s.Puissance_Fiscale = v.puissance_fiscale
    AND s.Boite_Vitesses = v.boite_vitesses
    AND s.Nombre_Portes = v.nombre_portes
INNER JOIN Dim_Condition c 
    ON s.Origine = c.origine 
    AND s.Premiere_Main = c.premiere_main 
    AND s.Etat = c.etat;

-- ÉTAPE 6 : VUE ANALYTIQUE MÉTIER & SÉCURITÉ DES ACCÈS (DCL)

CREATE OR REPLACE VIEW vw_avito_analytics AS
SELECT 
    f.id_fact,
    f.id_annonce,
    l.ville,
    l.secteur,
    v.marque,
    v.modele,
    v.annee_modele,
    v.age_vehicule,
    v.type_carburant,
    v.puissance_fiscale,
    v.boite_vitesses,
    v.nombre_portes,
    c.origine,
    c.premiere_main,
    c.etat,
    f.tranche_kilometrage,
    f.km_moyen,
    f.prix,
    f.nb_equipements,
    ROUND(f.prix / NULLIF(v.puissance_fiscale, 0), 0) AS prix_par_cv_fiscal
FROM Fact_Annonces f
INNER JOIN Dim_Localisation l ON f.id_localisation = l.id_localisation
INNER JOIN Dim_Vehicule v ON f.id_vehicule = v.id_vehicule
INNER JOIN Dim_Condition c ON f.id_condition = c.id_condition;

-- Gestion des droits d'accès (DCL) : Utilisateur dédié au reporting BI (Lecture Seule)
CREATE USER IF NOT EXISTS 'powerbi_reader'@'localhost' IDENTIFIED BY '<MOT_DE_PASSE_A_DEFINIR>';
GRANT SELECT ON avito_bi_dw.* TO 'powerbi_reader'@'localhost';
FLUSH PRIVILEGES;

-- ÉTAPE 7 : AUDIT FINAL & REQUÊTE ANALYTIQUE AVANCÉE (CTE + WINDOW FUNCTIONS)

SELECT 
    (SELECT COUNT(*) FROM staging_avito) AS Lignes_Staging,
    (SELECT COUNT(*) FROM Dim_Localisation) AS Nb_Localisations,
    (SELECT COUNT(*) FROM Dim_Vehicule) AS Nb_Vehicules,
    (SELECT COUNT(*) FROM Dim_Condition) AS Nb_Conditions,
    (SELECT COUNT(*) FROM Fact_Annonces) AS Nb_Faits_Annonces;

WITH Analyse_Marques AS (
    SELECT 
        v.marque,
        COUNT(f.id_fact) AS volume_annonces,
        ROUND(AVG(f.prix), 0) AS prix_moyen_mad,
        ROUND(AVG(f.km_moyen), 0) AS km_moyen,
        ROUND(AVG(v.age_vehicule), 1) AS age_moyen_ans
    FROM Fact_Annonces f
    INNER JOIN Dim_Vehicule v ON f.id_vehicule = v.id_vehicule
    GROUP BY v.marque
    HAVING COUNT(f.id_fact) >= 100
)
SELECT 
    marque,
    volume_annonces,
    ROUND(100.0 * volume_annonces / SUM(volume_annonces) OVER (), 2) AS part_de_marche_pct,
    prix_moyen_mad,
    km_moyen,
    age_moyen_ans,
    RANK() OVER (ORDER BY volume_annonces DESC) AS rang_volume,
    RANK() OVER (ORDER BY prix_moyen_mad DESC) AS rang_prix
FROM Analyse_Marques
ORDER BY volume_annonces DESC
LIMIT 10;