library(tidyverse)
library(tmap)
library(sf)
library(mapme.biodiversity)
library(geodata)

sf_use_s2(TRUE) 
ap <- st_read("data/Vahatra/Shapefiles/AP_Vahatra.shp") %>%
  st_transform(4326)

mada <- gadm("Madagascar", level = 3, resolution = 2, path = "data") %>%
  st_as_sf() %>%
  st_transform(4326)

mora <- mada %>%
  filter(NAME_3 == "Moramanga")

ambato <- ap %>%
  filter(nom == "Ambatotsirongorongo")
mikea <- ap %>%
  filter(nom == "Ambatotsirongorongo")

# Surface des hexagones en km2
taille_hex <-1 

cadre_autour_ambato = st_as_sf(st_as_sfc(st_bbox(ambato)))
cadre_autour_mikea = st_as_sf(st_as_sfc(st_bbox(mikea)))

# Cellules de 5km de rayon
surface_cellule <- taille_hex * (1e+6)
taille_cellule <- 2 * sqrt(surface_cellule / ((3 * sqrt(3) / 2))) * sqrt(3) / 2
grille_ambato <- st_make_grid(x = cadre_autour_ambato,
                            cellsize = taille_cellule,
                            square = FALSE) %>%
  st_sf()
 grille_mikea <- st_make_grid(x = cadre_autour_mikea,
                              cellsize = taille_cellule,
                              square = FALSE) %>%
  st_sf()


tmap_mode("view")
tm_shape(ambato) + 
  tm_polygons(col = "darkgreen", alpha = 0.4) + 
  tm_shape(grille_ambato) + 
  tm_borders()

tm_shape(mikea) + 
  tm_polygons(col = "darkgreen", alpha = 0.4) + 
  tm_shape(grille_mikea) + 
  tm_borders()
