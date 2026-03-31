# Load shared data and libraries
# Source this file at the top of every QMD chapter

library(tidyverse)
library(sf)
library(fixest)
library(gt)
library(scales)
library(knitr)
library(patchwork)
library(gsynth)
library(ggspatial)
library(ggrepel)

# -- Constants -----------------------------------------------------------------
TREAT_YEAR_MARO <- 2003L
TREAT_YEAR_ALA  <- 2008L
TREAT_YEAR_FARA <- 2006L
TREAT_YEAR_TOL  <- 2007L
TREAT_YEAR_FEN  <- 2007L

CLEAN_DONOR_OBS <- c("02", "13", "16", "25", "41")
ALL_DONOR_OBS   <- c("02", "12", "13", "15", "16", "23", "24", "25", "41")

STUDY_START <- 1999L
STUDY_END   <- 2014L

# -- Load household data -------------------------------------------------------
household_consolidated <- read_rds("data/household_consolidated.rds") |>
  mutate(
    obs     = substr(j5, 1, 2),
    site_id = substr(j5, 1, 3)
  )

# OECD-modified equivalence scale
oecd_scales <- read_rds("data/oecd_equiv_scale.rds")
household_consolidated <- household_consolidated |>
  left_join(oecd_scales, by = c("j5", "year")) |>
  mutate(oecd_equiv = replace_na(oecd_equiv, 1))

# -- Load spatial data ---------------------------------------------------------
# Protected areas (WDPA dynamic boundaries)
wdpa <- read_rds("data/dynamic_wdpa.rds") |> st_make_valid()
ankarafantsika_pa <- wdpa |> filter(grepl("Ankarafantsika", NAME))
alaotra_pa        <- wdpa |> filter(grepl("Lac Alaotra", NAME))

# Observatory communes
if (file.exists("data/Observatoires_ROS_communes_COD_v4.gpkg")) {
  obs_communes <- st_read("data/Observatoires_ROS_communes_COD_v4.gpkg", quiet = TRUE)
}
