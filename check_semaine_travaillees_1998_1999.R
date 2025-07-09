library(haven)
library(dplyr)
library(ggplot2)
library(purrr)

# Fonction pour extraire et préparer a3c
extract_a3c <- function(year) {
  read_dta(paste0("data/ROS_MDG_microdata/", year, "/res_m_a.dta")) %>%
    select(year, j5, a3c) %>%
    mutate(year = year)
}

# Appliquer à 1998 et 1999
a3c_data <- map_dfr(1998:1999, extract_a3c)

# Filtrer les valeurs non nulles
a3c_nonzero <- a3c_data %>%
  filter(!is.na(a3c), a3c > 0)

# Résumé statistique
summary_stats <- a3c_nonzero %>%
  group_by(year) %>%
  summarise(
    n = n(),
    mean = mean(a3c),
    median = median(a3c),
    sd = sd(a3c),
    min = min(a3c),
    max = max(a3c),
    p99 = quantile(a3c, 0.99)
  )

print(summary_stats)

# Histogramme
ggplot(a3c_nonzero, aes(x = a3c)) +
  geom_histogram(bins = 100, fill = "steelblue", color = "white") +
  facet_wrap(~year, scales = "free_y") +
  labs(
    title = "Distribution du revenu hebdomadaire par activité (a3c)",
    x = "Revenu hebdomadaire (en milliers d’ariary ?)", 
    y = "Nombre d'observations"
  ) +
  theme_minimal()
# Calcul des statistiques descriptives
a3c_summary_table <- a3c_nonzero %>%
  group_by(year) %>%
  summarise(
    n = n(),
    mean = mean(a3c, na.rm = TRUE),
    median = median(a3c, na.rm = TRUE),
    sd = sd(a3c, na.rm = TRUE),
    min = min(a3c, na.rm = TRUE),
    max = max(a3c, na.rm = TRUE),
    p99 = quantile(a3c, 0.99, na.rm = TRUE),
    .groups = "drop"
  )

# Affichage du tableau
a3c_summary_table
