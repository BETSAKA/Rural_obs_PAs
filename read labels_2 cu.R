library(tidyverse)
library(haven)

# Fonction générique de vérification par fichier et variables clés
inspect_vars_presence <- function(year, file_name, required_vars) {
  file_path <- paste0("data/ROS_MDG_microdata/", year, "/", file_name)
  
  if (!file.exists(file_path)) {
    return(tibble(year = year, file = file_name, var_name = NA, present = FALSE))
  }
  
  vars_in_file <- names(read_dta(file_path, n_max = 1))
  
  tibble(
    year = year,
    file = file_name,
    var_name = required_vars,
    present = required_vars %in% vars_in_file
  )
}

# Spécifie les fichiers et les variables critiques pour le calcul de rev_cu
files_and_vars <- tribble(
  ~file,          ~vars,
  "res_c.dta",    c("j5", "c1", "c37", "c2", "c4", "c6b", "c3a", "c3b"),
  "res_mo3.dta",  c("mo31c", "mo31e", "mo61a", "mo32", "mo61c", "mo44"),
  "res_itb.dta",  c("itb5")
)

# Appliquer la vérification sur toutes les années et fichiers/variables
years <- 1995:2015

revcu_varcheck <- pmap_dfr(
  expand.grid(year = years, file = files_and_vars$file, stringsAsFactors = FALSE),
  function(year, file) {
    required_vars <- files_and_vars %>% filter(file == !!file) %>% pull(vars) %>% .[[1]]
    inspect_vars_presence(year, file, required_vars)
  }
)

# Résumé : combien de variables critiques sont présentes par fichier/année
revcu_summary <- revcu_varcheck %>%
  group_by(year, file) %>%
  summarise(n_required = n(),
            n_present = sum(present),
            .groups = "drop") %>%
  mutate(ok = n_required == n_present)

revcu_summary_wide <- revcu_summary %>%
  select(year, file, ok) %>%
  pivot_wider(names_from = file, values_from = ok, values_fill = FALSE)

