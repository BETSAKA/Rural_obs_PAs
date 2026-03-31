# Shared ggplot2 theme and colour palettes
# Source after load_data.R

# -- Theme ---------------------------------------------------------------------
theme_paper <- function(base_size = 12) {
  theme_minimal(base_size = base_size) +
    theme(
      plot.title = element_text(face = "bold", size = rel(1.1)),
      plot.subtitle = element_text(color = "grey40"),
      panel.grid.minor = element_blank(),
      legend.position = "bottom"
    )
}

# -- Colour palettes -----------------------------------------------------------
# Treatment status
col_treated <- "#E41A1C"
col_control <- "#377EB8"
col_counterfactual <- "#999999"

# IUCN categories
col_iucn <- c(
  "II"  = "#E41A1C",   # strict (red)
  "IV"  = "#FF7F00",   # habitat/species (orange)
  "V"   = "#4DAF4A",   # landscape (green)
  "VI"  = "#377EB8"    # multipurpose (blue)
)

# Observatory colours (for maps)
col_obs <- c(
  "Marovoay"       = "#E41A1C",
  "Alaotra"        = "#377EB8",
  "Farafangana"    = "#4DAF4A",
  "Toliara North"  = "#FF7F00",
  "Fénérive East"  = "#984EA3",
  "Donor"          = "#999999"
)
