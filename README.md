# Rural_obs_PAs

This repository aims at analysing houshold conditions around protected areas based on rural observatory data.

# Préparation des fichiers

Pour utiliser ce code sous RStudio, commencez par cloner ce dépôt sur votre machine locale. Ouvrez RStudio et créez un nouveau projet en sélectionnant "File" > "New Project" > "Version Control" > "Git". Entrez l'URL du dépôt GitHub et choisissez un répertoire local où cloner le projet.

Le fichier .gitignore est utilisé pour spécifier les fichiers et répertoires à exclure de la synchronisation avec le dépôt Git. Par exemple, le dossier data/* est exclu car il contient des données volumineuses et confidentielles.

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

# Installation des dépendances
Avant d'exécuter les scripts, assurez-vous d'installer les packages R nécessaires. Vous pouvez utiliser le fichier `install_packages.R` pour installer toutes les dépendances :

```r
install_packages()
```
# Contributions

