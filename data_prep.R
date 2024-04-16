
library(tidyverse)
library(sf)
library(readxl)

# Clean municipality registry ---------------------------------------------
file.remove("data/Observatoires_ROS_communes_COD_v4.gpkg")
observatory_names <- read_xlsx("data/observatory_names.xlsx")
obs_communes <- st_read(
  "data/Observatoires_ROS_communes_COD_v3.gpkg",
  quiet = TRUE) %>%
  left_join(select(observatory_names, name, code), 
            by = c("OBS_NAME" = "name")) %>%
  rename(OBS_CODE = code)
obs_communes2 <- obs_communes %>% 
  mutate(to_remove = ADM3_EN == "Marovoay",
         OBS_Y_N = ifelse(to_remove, NA, OBS_Y_N),
         OBS_NAME = ifelse(to_remove, NA, OBS_NAME),
         SOURCE_OBS = ifelse(to_remove, NA, SOURCE_OBS)) %>%
  select(-to_remove) %>%
    mutate(to_add = ADM3_EN == "Tsaraotana",
           OBS_Y_N = ifelse(to_add, 1, OBS_Y_N),
           OBS_NAME = ifelse(to_add, "Menabe North-East", OBS_NAME),
           SOURCE_OBS = ifelse(to_add, "FB_correct", SOURCE_OBS)) %>%
             select(-to_add) 
st_write(obs_communes2, "data/Observatoires_ROS_communes_COD_v4.gpkg")
