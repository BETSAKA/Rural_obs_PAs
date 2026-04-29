# Conservation impacts on rural household welfare — Madagascar Rural Observatories

*La version française se trouve ci-dessous — French version below.*

**Live book (EN):** <https://betsaka.github.io/Rural_obs_PAs/>  
**Live book (FR):** <https://betsaka.github.io/Rural_obs_PAs/fr/>

---

## Overview

This repository contains the analysis and manuscript for a study of the welfare effects of protected area creation on adjacent rural households in Madagascar, using longitudinal data from the Rural Observatory System (ROS/SOR, 1995–2015) and a 2025 resurvey.

The study compares two conservation governance types:

- **Ankarafantsika National Park** (strict, IUCN II) — treatment from 2003 extension
- **Lac Alaotra Protected Landscape** (multipurpose, IUCN V) — treatment from 2007/2008

Three extension sites (Farafangana, Fénérive East, Toliara North) are analysed in a separate chapter. The primary identification strategy is a generalised synthetic control model (gsynth), complemented by within-observatory Callaway–Sant'Anna DiD checks using the 2025 resurvey data.

The book is bilingual (English / French) using `babelquarto`.

## Repository structure

```
_quarto.yml              # Book configuration (babelquarto)
_variables.yml           # Shared inline variables (ATTs, CIs, p-values...)
index.qmd / index.fr.qmd
01_context.qmd / .fr.qmd
02_data.qmd / .fr.qmd
03_strategy.qmd / .fr.qmd
04_results.qmd / .fr.qmd
05_extensions.qmd / .fr.qmd
06_discussion.qmd / .fr.qmd
references.qmd / .fr.qmd
A1_data_pipeline.qmd / .fr.qmd
A2_donor_validity.qmd / .fr.qmd
A3_robustness.qmd / .fr.qmd
A4_methodology.qmd / .fr.qmd
R/                       # Helper scripts (load_data.R, gsynth_helpers.R, plot_themes.R)
data/                    # Data files (gitignored — see below)
docs/                    # Rendered HTML output (deployed via GitHub Pages)
documentation/           # Internal notes and strategy documents
```

## Data

Survey data are confidential and excluded from the repository via `.gitignore`. To reproduce the analyses, place the ROS microdata in:

```
data/
└── ROS_MDG_microdata/
    ├── 1995/
    ├── ...
    └── 2025/
```

## Rendering

The book uses [`babelquarto`](https://docs.ropensci.org/babelquarto/) to render both language versions simultaneously. Standard `quarto render` will **not** produce the French version.

```r
babelquarto::render_book(
  preview  = FALSE,
  site_url = "https://betsaka.github.io/Rural_obs_PAs"
)
```

The rendered output goes to `docs/` and is deployed via GitHub Pages from the `main` branch.

## Dependencies

Install required R packages:

```r
source("install_packages.R")
```

Key packages: `gsynth`, `did`, `tidyverse`, `sf`, `gt`, `patchwork`, `babelquarto`, `quarto`.

## Issues and contributions

Use the [Issues](https://github.com/BETSAKA/Rural_obs_PAs/issues) tab for bug reports, questions, or suggestions.

---

# Impacts de la conservation sur le bien-être des ménages ruraux — Observatoires ruraux de Madagascar

*English version above — La version anglaise se trouve ci-dessus.*

**Livre en ligne (EN) :** <https://betsaka.github.io/Rural_obs_PAs/>  
**Livre en ligne (FR) :** <https://betsaka.github.io/Rural_obs_PAs/fr/>

---

## Vue d'ensemble

Ce dépôt contient l'analyse et le manuscrit d'une étude sur les effets de la création d'aires protégées sur le bien-être des ménages ruraux adjacents à Madagascar, à partir des données longitudinales du Système des Observatoires Ruraux (SOR/ROS, 1995–2015) et d'une ré-enquête en 2025.

L'étude compare deux types de gouvernance de la conservation :

- **Parc National d'Ankarafantsika** (strict, catégorie II UICN) — exposition à partir de l'extension de 2003
- **Paysage Harmonieux Protégé du Lac Alaotra** (multifonctionnel, catégorie V UICN) — exposition à partir de 2007/2008

Trois sites d'extension (Farafangana, Fénérive Est, Toliara Nord) sont analysés dans un chapitre séparé. La stratégie d'identification principale est un modèle de contrôle synthétique généralisé (gsynth), complété par des vérifications DiD intra-observatoire Callaway–Sant'Anna utilisant les données de ré-enquête 2025.

Le livre est bilingue (anglais / français) grâce à `babelquarto`.

## Structure du dépôt

```
_quarto.yml              # Configuration du livre (babelquarto)
_variables.yml           # Variables inline partagées (ATT, IC, p-valeurs...)
index.qmd / index.fr.qmd
01_context.qmd / .fr.qmd
02_data.qmd / .fr.qmd
03_strategy.qmd / .fr.qmd
04_results.qmd / .fr.qmd
05_extensions.qmd / .fr.qmd
06_discussion.qmd / .fr.qmd
references.qmd / .fr.qmd
A1_data_pipeline.qmd / .fr.qmd
A2_donor_validity.qmd / .fr.qmd
A3_robustness.qmd / .fr.qmd
A4_methodology.qmd / .fr.qmd
R/                       # Scripts utilitaires (load_data.R, gsynth_helpers.R, plot_themes.R)
data/                    # Données (exclues du dépôt — voir ci-dessous)
docs/                    # Sortie HTML rendue (déployée via GitHub Pages)
documentation/           # Notes internes et documents de stratégie
```

## Données

Les données d'enquête sont confidentielles et exclues du dépôt via `.gitignore`. Pour reproduire les analyses, placez les microdonnées ROS dans :

```
data/
└── ROS_MDG_microdata/
    ├── 1995/
    ├── ...
    └── 2025/
```

## Rendu

Le livre utilise [`babelquarto`](https://docs.ropensci.org/babelquarto/) pour rendre les deux versions linguistiques simultanément. La commande standard `quarto render` ne produira **pas** la version française.

```r
babelquarto::render_book(
  preview  = FALSE,
  site_url = "https://betsaka.github.io/Rural_obs_PAs"
)
```

Le résultat rendu est placé dans `docs/` et déployé via GitHub Pages depuis la branche `main`.

## Dépendances

Installez les packages R nécessaires :

```r
source("install_packages.R")
```

Packages principaux : `gsynth`, `did`, `tidyverse`, `sf`, `gt`, `patchwork`, `babelquarto`, `quarto`.

## Issues et contributions

Utilisez l'onglet [Issues](https://github.com/BETSAKA/Rural_obs_PAs/issues) pour signaler des bugs, poser des questions ou faire des suggestions.

