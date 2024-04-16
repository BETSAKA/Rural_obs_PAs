library(tidyverse)    # A series of packages for data manipulation
library(haven)        # Required for reading STATA files (.dta)
library(labelled)     # To work with labelled data from STATA
library(sf)           # for spatial data handling
library(stringdist)   # for string distance and matching
library(tmap)         # for mapping
library(fuzzyjoin)    # for fuzzy joining
library(readxl)       # Read data frames to Excel format
library(writexl)      # Write data frames to Excel format
library(gt)           # for nicely formatted tables


observatory_names <- read_xlsx("data/observatory_names.xlsx")

correspondence_obs <- read_rds("output/correspondence_table3.rds") %>%
  mutate(j0 = as.numeric(j0)) %>%
  left_join(observatory_names, by = c("j0" = "code")) %>%
  rename(OBS_NAME = name) %>%
  relocate(OBS_NAME, .before = j0)

correspondence_MNE <- correspondence_obs %>%
  filter(OBS_NAME == "Menabe North-East")

# Count unmatched (NA)
correspondence_MNE %>%
  group_by(method_village) %>%
  summarise(n = sum(obs_count)) %>%
  gt()

# Detail of missing observations
corr_na_MNE <- correspondence_MNE %>%
  filter(is.na(method_village))
corr_na_MNE %>%
  select(Municipality = j42, Village = j4, `Years of occurrence` = years,
         `Number of observations` = obs_count) %>%
  gt()

# Extract Fokontany from
obs_communes <- st_read(
  "data/Observatoires_ROS_communes_COD_v4.gpkg",
  quiet = TRUE) %>%
  left_join(select(observatory_names, name, code), 
            by = c("OBS_NAME" = "name")) %>%
  # rename(OBS_CODE = code) %>%
  filter(OBS_NAME == "Menabe North-East")

obs_fknt <- st_read(
  "data/OCHA_BNGRC admin boundaries/mdg_admbnda_adm4_BNGRC_OCHA_20181031.shp",
  quiet = TRUE) %>%
  filter(ADM3_PCODE %in% obs_communes$ADM3_PCODE)

obs_ppl <- st_read(
  "data/OCHA_BNGRC populated places/mdg_pplp_places_NGA_OCHA.shp",
  quiet = TRUE) %>%
  filter(str_replace(COM_PCODE, "MDG", "MG") %in% obs_communes$ADM3_PCODE)

# write_xlsx(list(corr_na_MNE, obs_fknt, obs_ppl),
#            path = "output/matches_Menabe_NE.xlsx")

# Manual addition of data

correspondence_table3 <- read_rds("output/correspondence_table3.rds")

edit_mne <- tibble::tribble(
  ~j0,          ~j42,                      ~j4,             ~ADM4_clean,     ~ADM4_PCODE,
  52L,  "Ambatolahy",             "Antevamena",  "Soaserana Antevamena", "MG54511091002",
  52L,  "Ankilizato",            "Andranovory",                      NA,              NA,
  52L,  "Ankilizato",             "Avaradrano", "Ankilizato Avaradrano", "MG54509091005",
  52L,  "Ankilizato",           "Malainkirafy",                      NA,              NA,
  52L,  "Ankilizato",                "Tanana?",                      NA,              NA,
  52L,       "Isalo",             "Antanambao",                "Bepeha", "MG54511072003",
  52L, "Malaimbandy",          "Ambonara Nord",         "Ambonara Nord", "MG54509130004",
  52L, "Malaimbandy",         "Anosibe Bevoay",                      NA,              NA,
  52L, "Malaimbandy",     "Antazoa/Matavirano",           "Malaimbandy", "MG54509130001",
  52L, "Malaimbandy",           "Mahasoa Nord",          "Mahasoa Nord", "MG54509130003",
  52L, "Malaimbandy", "Malaimbandy/Avaradrano",           "Malaimbandy", "MG54509130001",
  52L,  "Tsaraotana",            "Antsiraraky",           "Antsiraraky", "MG54510050001",
  52L,  "Tsaraotana",             "village 51",                      NA,              NA
)

# Joining
correspondence_table4 <- correspondence_table3 %>%
  left_join(mutate(edit_mne, j0 = as.character(j0)), by =c("j0", "j42", "j4")) %>%
  mutate(ADM4_clean = coalesce(ADM4_clean.y, ADM4_clean.x),
         ADM4_PCODE = coalesce(ADM4_PCODE.y, ADM4_PCODE.x)) 

# Extract Fokontany from
obs_communes <- st_read(
  "data/Observatoires_ROS_communes_COD_v4.gpkg",
  quiet = TRUE) %>%
  left_join(select(observatory_names, name, code), 
            by = c("OBS_NAME" = "name")) 

fokontany <- st_read(
  "data/OCHA_BNGRC admin boundaries/mdg_admbnda_adm4_BNGRC_OCHA_20181031.shp",
  quiet = TRUE) 

# Plot data
commmune_pcode_years <- correspondence_table4 %>%
  # Split and unnest the years
  mutate(years = str_split(years, ", ")) %>%
  unnest(years) %>%
  # Convert years to numeric for proper sorting
  mutate(years = as.numeric(years)) %>%
  # Group by ADM3_PCODE and extract unique, sorted years
  group_by(ADM3_PCODE) %>%
  summarize(years = list(unique(years))) %>%
  ungroup() %>%
  # Sort and collapse the years
  mutate(years = map_chr(years, ~ paste(sort(.x), collapse = ", ")))

fokontany_pcode_years <- correspondence_table4 %>%
  # Split and unnest the years
  mutate(years = str_split(years, ", ")) %>%
  unnest(years) %>%
  # Convert years to numeric for proper sorting
  mutate(years = as.numeric(years)) %>%
  # Group by ADM3_PCODE and extract unique, sorted years
  group_by(ADM4_PCODE) %>%
  summarize(years = list(unique(years))) %>%
  ungroup() %>%
  # Sort and collapse the years
  mutate(years = map_chr(years, ~ paste(sort(.x), collapse = ", ")))

selected_communes <- commmune_pcode_years %>%
  filter(!is.na(ADM3_PCODE)) %>%
  left_join(obs_communes, by = "ADM3_PCODE") %>%
  st_sf()

selected_fokontany <- fokontany_pcode_years %>%
  filter(!is.na(ADM4_PCODE)) %>%
  left_join(fokontany, by = "ADM4_PCODE") %>%
  st_sf()  %>%
  mutate(label = "Surveyed______")


makay_ap <- st_read("../available_data_makay2/data/Makay_wgs84.geojson", quiet = TRUE) %>% 
  rename(Statut = SOURCETHM) %>% 
  mutate(Statut = recode(Statut, "zone tampon" = "Zone tampon"))

# Fist we dissolve the different areas
makay_union <- makay_ap %>% 
  st_union() %>% 
  st_sf() %>% 
  st_make_valid()

# Create a dataframe of the coordinates
coordinates <- data.frame(
  location = c("Beroroha", "Beronono", "Tsivoko", "Makaykely"),
  latitude = c("21°40.504’S", "21°21.669’S", "21°17.712’S", "21°28.074’S"),
  longitude = c("45°9.571’E", "45°14.885’E", "45°22.732’E", "45°21.896’E")) 
# Function to parse DMS and convert to decimal degrees
ddm_to_decimal <- function(dms){
  # Extraire les degrés, minutes et secondes
  parts <- regmatches(dms, gregexpr("[0-9.]+", dms))[[1]]
  degree <- as.numeric(parts[1])
  minute <- as.numeric(parts[2]) / 60
  direction <- ifelse(grepl("S|W", dms), -1, 1)
  
  # Converstion au format décimal
  decimal <- direction * (degree + minute)
  
  return(decimal)
}
# Apply function to each coordinate
coordinates$latitude_decimal <- sapply(coordinates$latitude, ddm_to_decimal)
coordinates$longitude_decimal <- sapply(coordinates$longitude, ddm_to_decimal)

# Convertir les coordonnées en objet sf
Sites_OR_2020 <- st_as_sf(coordinates, 
                           coords = c("longitude_decimal", "latitude_decimal"), 
                           crs = 4326)

tmap_mode("view")
tm_shape(selected_communes) + 
  tm_fill(col = "OBS_NAME", palette = "Set1", title = "Observatory",
          id = "ADM3_EN", legend.show = FALSE,
          popup.vars = c("Observatory" = "OBS_NAME",
                         "Data collection years"  = "years",
                         "District" = "ADM2_EN",
                         "Region" = "ADM1_EN")) +
  tm_shape(selected_fokontany) + 
  tm_fill(col = "label", palette = c("black"), alpha = 0.6, title = "Fokontany", 
          id = "ADM4_EN", legend.show = FALSE,
          popup.vars = c("Observatory" = "OBS_NAME",
                         "Data collection years"  = "years",
                         "Commune" = "ADM3_EN",
                         "District" = "ADM2_EN",
                         "Region" = "ADM1_EN")) +
  tm_shape(makay_ap) +
  tm_polygons(col = "Statut", alpha = 0.5) +
  tm_shape(makay_union) +
  tm_borders(col = "darkblue") + 
  tm_shape(Sites_OR_2020) +
  tm_dots() +
  tm_basemap("OpenStreetMap") 
  tm_scale_bar()

