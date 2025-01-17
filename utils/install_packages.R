librairies_requises <- c( # On liste les librairies dont on a besoin
  "tidyverse", # Une série de packages pour faciliter la manipulation de données
  "readxl", # Pour lire les fichiers excel (Carvalho et al. 2018)
  "writexl", # Pour écrire des fichiers excel
  "gt", # Pour des rendus graphiques harmonisés html et pdf/LaTeX
  "sf", # Pour faciliter la manipulation de données géographiques
  "wdpar", # Pour télécharger simplement la base d'aires protégées WDPA
  "webdriver", # requis pour installer phantomjs pour wdpar
  "tmap", # Pour produire de jolies carte
  "geodata", # Pour télécharger simplement les frontières administratives
  "stargazer") # Reformater de manière plus lisible les résumé des régressions

# On regarde parmi ces librairies lesquelles ne sont pas installées
manquantes <- !(librairies_requises %in% installed.packages())
# On installe celles qui manquent
if(any(manquantes)) install.packages(librairies_requises[manquantes])