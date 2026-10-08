# 🚗 Observatoire du marché automobile d'occasion – Avito Maroc

Analyse de **8 097 annonces** de voitures d'occasion, prédiction du prix avec **XGBoost** et repérage des bonnes affaires dans un tableau de bord **Power BI**.

**Auteur :** Elmahdi Chiki



## Pipeline

`CSV brut (24 776 annonces)` → `Nettoyage Python (8 097 lignes)` → `MySQL (schéma en étoile)` → `XGBoost` → `Power BI`

* **Nettoyage** : déduplication, conversion du kilométrage, suppression des colonnes constantes et des prix aberrants.
* **MySQL** : table de faits, 3 dimensions, vue analytique, requête avec CTE et fonctions de fenêtrage.
* **Modèle** : XGBoost, évalué sur 20 % d'annonces gardées de côté.
* **Statut de l'offre** : bonne affaire si le prix affiché est inférieur de 12 000 MAD ou plus au prix prédit, sur-cotée s'il est supérieur de 12 000 MAD ou plus.

## Résultats

|R²|MAE|RMSE|
|-|-|-|
|**0,879**|**13 064 MAD** (environ 11 % du prix moyen)|21 426 MAD|

* Le prix médian baisse jusqu'à environ 15 ans (166 000 MAD à 1 an, 75 000 MAD à 15 ans), puis se stabilise.
* Casablanca concentre un quart des annonces.

## Structure

```
sql/        Pipeline.sql, schemas.mwb
notebooks/  Data\_cleaning.ipynb, XGBOOST.ipynb
powerbi/    Power\_BI.pbix
images/     captures du tableau de bord
data/       avito\_car\_dataset\_ALL.csv
```

## Utilisation

1. `pip install -r requirements.txt`
2. Remplacer le mot de passe MySQL factice dans les notebooks (ne le publiez jamais).
3. Exécuter : `Pipeline.sql` (étapes 1-2) → `Data\_cleaning.ipynb` → `Pipeline.sql` (étapes 3-7) → `XGBOOST.ipynb` → ouvrir le `.pbix`.

## Limites

* Le prix affiché n'est pas le prix de vente.
* Les prédictions portent aussi sur des annonces vues à l'entraînement, ce qui sous-estime légèrement les écarts.
* Le seuil fixe de 12 000 MAD classe plus souvent les voitures chères dans les catégories extrêmes.
* Annonces publiques utilisées à des fins pédagogiques uniquement.

**Technologies :** Python · pandas · scikit-learn · XGBoost · MySQL · Power BI

