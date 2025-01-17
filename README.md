# Impact des aires protégées sur les conditions des ménages à partir des données des observatoires ruraux à Madagascar

## Contexte

Des enquêtes d'observatoires ruraux ont été menées dans 26 zones géographiques entre 1995 et 2015. Des aires protégées ont été créées en bordure immédiate de plusieurs de ces zones. Dans le cadre du projet BETSAKA, on sélectionnera trois de ces zones pour mener de nouvelles enquêtes (2 en 2025, 3 en 2026), près de 10 ans plus tard, afin d'étudier l'évolution des conditions de vie attribuables à la conservation, en comparant les villages les plus proches des aires protégées et ceux qui en sont plus éloignés.

## Objectif

Ce dépôt vise à organiser le travail statistique visant à l'exploitation des données existantes et à la sélection des sites. Il est construit comme un cahier de laboratoire, avec un chapitre d'introduction (index.qmd) et des chapitres spécifiques (autres fichiers qmd). L'idée est de documenter les différents essais et travaux, et de fournir une base qui facilitera la production d'articles publiables.

Spécifiquement, il s'agit de :

-   **Exploitation des données existantes** : Analyser les données des enquêtes passées pour identifier les tendances et évaluer l'impact des aires protégées.

-   **Sélection des sites pour nouvelles Enquêtes** : Identifier les zones pertinentes et planifier les nouvelles enquêtes de 2025 et 2026.

-   **Documentation et méthodologie** : Documenter les méthodes statistiques utilisées et fournir un guide détaillé pour la reproduction des analyses.

-   **Diffusion des résultats** : Préparer des rapports et publications scientifiques, avec une reconnaissance équitable des contributions.

-   **Renforcement des Capacités** : Accompagner les collègues qui se familiarisent avec ces outils à prendre en main R et les pratiques de science ouverte.

## Préparation des fichiers

Pour utiliser ce code sous RStudio, commencez par cloner ce dépôt sur votre machine locale. Ouvrez RStudio et créez un nouveau projet en sélectionnant "File" \> "New Project" \> "Version Control" \> "Git". Entrez l'URL du dépôt GitHub et choisissez un répertoire local où cloner le projet.

Le fichier .gitignore est utilisé pour spécifier les fichiers et répertoires à exclure de la synchronisation avec le dépôt Git. Par exemple, le dossier data/\* est exclu car il contient des données volumineuses et confidentielles.

Le code a besoin des données pour fonctionner. Il faut donc coller les données des OR dans un sous dossier du dossier

```         
data
├── ROS_MDG_microdata
│   ├── 1995
│   ├── 1996
│   ├── 1997
│   ├── ...
│   └── 2015
```

## Installation des dépendances

Avant d'exécuter les scripts, assurez-vous d'installer les packages R nécessaires. Vous pouvez utiliser le fichier `install_packages.R` pour installer toutes les dépendances :

``` r
source("install_packages.R")
```

## Contributions

Les contributions sont les bienvenues ! Voici quelques moyens de contribuer :

-    **Création de nouveaux fichiers d'analyse** : Ajoutez de nouveaux fichiers R ou QMD pour analyser les données existantes ou nouvelles.

-    **Modification des fichiers existants** : Améliorez les fichiers existants en les modifiant pour ajouter des fonctionnalités, optimiser le code ou corriger des erreurs.

-    **Documentation** : Étoffez le README ou créez des notes de documentation pour aider les autres à comprendre et utiliser le code ou les données.

-    **Questions et problèmes** : Si vous rencontrez des difficultés ou avez des questions, créez un ticket dans la section "Issues" du repository en ligne.

## Comment poster des modifications

Pour poster vos modifications, voici plusieurs solutions :

1.   **Commit direct sur le dépôt** :

    -   Utilisez l'onglet "Git" dans RStudio pour faire un commit directement sur le dépôt.

    -   Note : Ce n'est pas idéal car il y a un risque d'insérer des erreurs, mais c'est plus simple pour commencer.

2.  **Créer un fork et faire une pull request** :

    -   Créez un fork du dépôt sur GitHub.

    -   Clonez votre fork sur votre machine locale en utilisant RStudio :

        -   Allez dans "File" \> "New Project" \> "Version Control" \> "Git".

        -   Entrez l'URL de votre fork et choisissez un répertoire local pour cloner le projet.

    -   Appliquez vos modifications et faites des commits en utilisant l'onglet "Git" dans RStudio.

    -   Proposez d'intégrer vos modifications en effectuant une pull request sur l'interface GitHub.

3.  **Utiliser l'interface en ligne pour poster des "Issues"** :

    -   Si vous avez des idées, des suggestions ou des problèmes, utilisez l'interface GitHub pour créer une "Issue".

## Instructions détaillées pour les débutants

Si vous n'avez jamais utilisé Git ou GitHub, voici des instructions simples pour vous aider à démarrer :

1.  **Forker le dépôt** :

    -   Allez sur la page GitHub du dépôt et cliquez sur le bouton "Fork" en haut à droite pour créer une copie de ce dépôt sur votre compte GitHub.

2.  **Cloner votre fork** :

    -   Ouvrez RStudio.

    -   Allez dans "File" \> "New Project" \> "Version Control" \> "Git".

    -   Entrez l'URL de votre fork GitHub et choisissez un répertoire local où cloner le projet.

3.  **Créer une nouvelle branche** :

    -   Dans RStudio, ouvrez l'onglet "Git".

    -   Cliquez sur "New Branch", donnez un nom descriptif à votre branche, puis cliquez sur "Create".

4.  **Faire des modifications**

    -   Ouvrez les fichiers dans RStudio, faites vos modifications ou ajoutez de nouveaux fichiers, puis enregistrez-les.

5.  **Commiter vos changements** :

    -   Sélectionnez les fichiers modifiés dans le panneau "Git" de RStudio.

    -   Cliquez sur "Commit", ajoutez un message descriptif pour vos changements, puis cliquez sur "Commit".

    -   Cliquez sur "Push" pour envoyer vos modifications à votre fork sur GitHub.

6.  **Ouvrir une Pull Request**

    -   Allez sur la page GitHub de votre fork.

    -   Cliquez sur "Compare & pull request".

    -   Décrivez vos modifications et soumettez la Pull Request.

## Wiki

Consultez [le Wiki du projet](https://github.com/BETSAKA/Tools/wiki) pour des guides détaillés, des tutoriels et des informations supplémentaires sur le projet. Vous pouvez également contribuer au Wiki en ajoutant ou en modifiant des pages pour partager vos connaissances et ressources.

### Issues

Si vous rencontrez des problèmes, avez des questions ou souhaitez suggérer des améliorations, utilisez la section [Issues](https://github.com/votre-utilisateur/Rural_obs_PAs/issues) du dépôt. Vous pouvez créer une nouvelle issue pour signaler un bug, poser une question ou proposer une nouvelle fonctionnalité. N'oubliez pas de vérifier les issues existantes avant d'en créer une nouvelle pour éviter les doublons.
