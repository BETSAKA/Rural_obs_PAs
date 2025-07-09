library(tidyverse)
library(haven)
# Fonction pour extraire noms et labels des variables a3* pour une année donnée
inspect_a3_vars <- function(year) {
  file_path <- paste0("data/ROS_MDG_microdata/", year, "/res_m_a.dta")
  
  # Lire l'en-tête uniquement pour éviter les gros chargements
  df <- read_dta(file_path, col_select = everything())
  
  # Extraire noms et labels des variables commençant par "a3"
  a3_vars <- names(df)[str_starts(names(df), "a3")]
  
  tibble(
    year = year,
    var_name = a3_vars,
    var_label = map_chr(a3_vars, ~ attr(df[[.x]], "label") %||% NA_character_)
  )
}

# Appliquer pour 1995 et 1996
a3_var_labels <- map_dfr(1996:2015, inspect_a3_vars) 


a3_var_labels_wide <- a3_var_labels %>%
  pivot_wider(names_from = year, values_from = var_label)
# Afficher le tableau
a3_var_labels