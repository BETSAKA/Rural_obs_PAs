library(tidyverse)
library(haven)


inspect_vars_by_prefix <- function(year, prefix_vec, file_name) {
  file_path <- paste0("data/ROS_MDG_microdata/", year, "/", file_name)
  message("Lecture du fichier : ", file_path)
  
  if (!file.exists(file_path)) {
    warning("Fichier manquant pour l'année ", year)
    return(tibble(year = year, var_name = character(), var_label = character()))
  }
  
  df <- read_dta(file_path, col_select = everything())
  
  # Filtrage sur les préfixes, insensible à la casse
  var_names <- names(df)[map_lgl(names(df), function(n) any(str_starts(tolower(n), tolower(prefix_vec))))]
  
  message(length(var_names), " variables trouvées pour l'année ", year)
  
  if (length(var_names) == 0) {
    return(tibble(year = year, var_name = character(), var_label = character()))
  }
  
  tibble(
    year = year,
    var_name = var_names,
    var_label = map_chr(var_names, ~ attr(df[[.x]], "label") %||% NA_character_)
  )
}


prefixes <- c("as2", "as3", "as4")
years <- 1995:2015

all_labels <- map_dfr(years, ~inspect_vars_by_prefix(.x, prefixes, 
                                                        file_name = "res_as.dta"))

all_labels_wide <- all_labels %>%
pivot_wider(names_from = year, values_from = var_label)

