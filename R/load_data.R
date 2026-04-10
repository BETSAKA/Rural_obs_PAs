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

# Disable s2 spherical geometry to avoid degenerate-edge errors with WDPA data
sf_use_s2(FALSE)

# -- Constants -----------------------------------------------------------------
TREAT_YEAR_MARO <- 2003L
TREAT_YEAR_ALA <- 2008L
TREAT_YEAR_FARA <- 2006L
TREAT_YEAR_TOL <- 2007L
TREAT_YEAR_FEN <- 2007L

CLEAN_DONOR_OBS <- c("02", "13", "16", "25", "41")
ALL_DONOR_OBS <- c("02", "12", "13", "15", "16", "23", "24", "25", "41")
TREATED_OBS <- c("03", "21", "15", "23", "24")
ALL_OBS_14 <- c(TREATED_OBS, CLEAN_DONOR_OBS)

STUDY_START <- 1999L
STUDY_END <- 2014L
STUDY_START_DT <- as.Date("1999-01-01")
STUDY_END_DT <- as.Date("2014-12-31")
THRESHOLD_KM <- 20L

# PA colour palette (per treatment arm)
PA_COLS <- c(
  "Marovoay (strict)" = "#D32F2F",
  "Alaotra (multipurpose)" = "#1565C0",
  "Farafangana (multipurpose)" = "#2E7D32",
  "Toliara North (mixed)" = "#E65100",
  "Fénérive East (low int.)" = "#6A1B9A"
)

# -- Load household data -------------------------------------------------------
household_consolidated <- read_rds("data/household_consolidated.rds") |>
  mutate(
    obs = substr(j5, 1, 2),
    site_id = substr(j5, 1, 3)
  )

# OECD-modified equivalence scale
oecd_scales <- read_rds("data/oecd_equiv_scale.rds")
household_consolidated <- household_consolidated |>
  left_join(oecd_scales, by = c("j5", "year")) |>
  mutate(oecd_equiv = replace_na(oecd_equiv, 1))

# -- Load spatial data ---------------------------------------------------------
# Madagascar country outline (from rnaturalearth if available, else from WDPA hull)
if (requireNamespace("rnaturalearth", quietly = TRUE)) {
  madagascar <- rnaturalearth::ne_countries(
    scale = 50,
    country = "Madagascar",
    returnclass = "sf"
  ) |>
    st_make_valid()
} else {
  # Fallback: convex hull of all WDPA geometries (approximate outline)
  madagascar <- NULL
}

# Protected areas (WDPA dynamic boundaries)
wdpa <- read_rds("data/dynamic_wdpa.rds") |> st_make_valid()

# PA boundaries: consolidated study-period states (external boundary only)
dyn_study <- wdpa |>
  filter(
    zone_type == "external_boundary",
    valid_from <= STUDY_END_DT,
    is.na(valid_to) | valid_to >= STUDY_START_DT
  ) |>
  group_by(WDPAID, NAME) |>
  summarise(
    geometry = st_union(geometry),
    valid_from = min(valid_from, na.rm = TRUE),
    .groups = "drop"
  ) |>
  st_make_valid()

# Individual PA extractions — latest non-Ramsar external boundary only
ankarafantsika_pa <- wdpa |>
  filter(grepl("Ankarafantsika", NAME), !grepl("Ramsar", DESIG_ENG),
         zone_type == "external_boundary") |>
  filter(is.na(valid_to)) |>
  slice_max(valid_from, n = 1)

# Pre-2002 RNI boundary (before the 2002 national park extension)
ankarafantsika_rni <- wdpa |>
  filter(grepl("Ankarafantsika", NAME), !grepl("Ramsar", DESIG_ENG),
         zone_type == "external_boundary", state_id == "1299_1927")

alaotra_pa <- wdpa |>
  filter(grepl("Lac Alaotra", NAME), !grepl("Ramsar", DESIG_ENG)) |>
  filter(is.na(valid_to)) |>
  slice_max(valid_from, n = 1)

# CAZ / Zahamena — not in the dynamic WDPA; loaded from WDPA snapshot
if (file.exists("data/caz_zahamena_wdpa.rds")) {
  .caz_zah <- read_rds("data/caz_zahamena_wdpa.rds") |> st_make_valid()
  caz_pa <- .caz_zah |> filter(grepl("Corridor", name))
  zahamena_pa <- .caz_zah |> filter(!grepl("Corridor", name))
} else {
  caz_pa <- wdpa |> filter(grepl("Ankeniheny Zahamena", NAME))
  zahamena_pa <- wdpa |>
    filter(grepl("Zahamena", NAME) & !grepl("Ankeniheny", NAME))
}

# Observatory communes
obs_communes <- st_read(
  "data/Observatoires_ROS_communes_COD_v4.gpkg",
  quiet = TRUE
) |>
  st_make_valid() |>
  mutate(OBS_CODE = as.integer(OBS_CODE))

# Per-observatory commune subsets
maro_communes <- obs_communes |> filter(OBS_CODE == 3)
ala_communes <- obs_communes |> filter(OBS_CODE == 21)
fara_communes <- obs_communes |> filter(OBS_CODE == 15)
tol_communes <- obs_communes |> filter(OBS_CODE == 23)
fen_communes <- obs_communes |> filter(OBS_CODE == 24)

# -- Surveyed fokontany (georeferenced in Andrianjafindrainibe et al. 2024) ----
sel_fokontany <- read_rds("data/georeferencing/selected_fokontany.rds") |>
  st_make_valid() |>
  left_join(
    obs_communes |> st_drop_geometry() |> distinct(ADM3_PCODE, OBS_CODE),
    by = "ADM3_PCODE",
    relationship = "many-to-many"
  )

# Per-observatory fokontany subsets
maro_fokontany <- sel_fokontany |> filter(OBS_CODE == 3)
ala_fokontany <- sel_fokontany |> filter(OBS_CODE == 21)
fara_fokontany <- sel_fokontany |> filter(OBS_CODE == 15)
tol_fokontany <- sel_fokontany |> filter(OBS_CODE == 23)
fen_fokontany <- sel_fokontany |> filter(OBS_CODE == 24)

# -- OSM water features (cached) ----------------------------------------------
osm_water_maro <- read_rds("data/osm_water_maro.rds")
osm_water_ala <- read_rds("data/osm_water_ala.rds")

# -- Fokontany coordinates (2025 GPS) -----------------------------------------
maro_fkt <- tibble(
  fokontany = c("Bepako", "Madiromiongana", "Ampijoroa", "Maroala"),
  site_id = c("031", "032", "033", "034"),
  lon = c(46.658402, 46.749270, 46.477984, 46.539738),
  lat = c(-16.163712, -16.086480, -16.233414, -16.228857),
  river_side = c("east", "east", "west", "west"),
  treated = c(TRUE, TRUE, FALSE, FALSE)
) |>
  st_as_sf(coords = c("lon", "lat"), crs = 4326)
maro_fkt$dist_km <- round(
  as.numeric(st_distance(maro_fkt, st_union(ankarafantsika_pa))) / 1000,
  1
)
maro_fkt$dist_rni_km <- round(
  as.numeric(st_distance(maro_fkt, st_union(ankarafantsika_rni))) / 1000,
  1
)

ala_fkt <- tibble(
  fokontany = c(
    "Avaradrano",
    "Feramanga Atsimo",
    "Mangabe",
    "Analamiranga",
    "Maritampona",
    "Ambohidrony",
    "Ambatomanga"
  ),
  lon = c(
    48.469958,
    48.373383,
    48.405244,
    48.200017,
    48.207639,
    48.208611,
    48.200647
  ),
  lat = c(
    -17.805414,
    -17.844153,
    -17.879586,
    -17.572375,
    -17.603500,
    -17.729175,
    -17.741178
  )
) |>
  st_as_sf(coords = c("lon", "lat"), crs = 4326)
ala_fkt$dist_php <- round(
  as.numeric(st_distance(ala_fkt, st_union(alaotra_pa))) / 1000,
  1
)
if (nrow(caz_pa) > 0) {
  ala_fkt$dist_caz <- round(
    as.numeric(st_distance(ala_fkt, st_union(caz_pa))) / 1000,
    1
  )
} else {
  ala_fkt$dist_caz <- Inf
}
ala_fkt$nearest_pa <- if_else(
  ala_fkt$dist_caz < ala_fkt$dist_php,
  "Corridor Ankeniheny-Zahamena",
  "Lac Alaotra PHP"
)

# -- Observatory locations table -----------------------------------------------
obs_locations <- tibble(
  code = c("02", "03", "13", "15", "16", "21", "23", "24", "25", "41"),
  name = c(
    "Antsirabe",
    "Marovoay",
    "Tsiroanomandidy",
    "Farafangana",
    "Ambovombe",
    "Alaotra",
    "Toliara North",
    "Fénérive East",
    "Mahanoro",
    "Itasy"
  ),
  latitude = c(
    -19.8667,
    -16.1000,
    -18.7714,
    -22.8167,
    -25.0333,
    -17.5833,
    -23.3893,
    -17.3833,
    -20.4000,
    -19.0500
  ),
  longitude = c(
    47.0333,
    46.6333,
    46.0546,
    47.8333,
    46.0833,
    48.4167,
    43.7761,
    49.4167,
    48.8000,
    46.7354
  ),
  role = case_when(
    code == "03" ~ "Marovoay (strict, 2003)",
    code == "21" ~ "Alaotra (multipurpose, 2008)",
    code %in% c("15", "23", "24") ~ "New treated (2006–2007)",
    .default = "Clean donor pool"
  )
) |>
  mutate(
    role = factor(
      role,
      levels = c(
        "Marovoay (strict, 2003)",
        "Alaotra (multipurpose, 2008)",
        "New treated (2006–2007)",
        "Clean donor pool"
      )
    )
  )
