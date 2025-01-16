library(tidyverse)
library(tmap)
library(sf)
library(mapme.biodiversity)
library(geodata)

sf_use_s2(TRUE)

# Load and transform the shapefile to WGS84
ap <- st_read("data/Vahatra/Shapefiles/AP_Vahatra.shp") %>%
  st_transform(4326)

# Filter for the Mikea protected area
mikea <- ap %>%
  filter(nom == "Mikea")

# Define the size of the hexagons in km2
taille_hex <- 1

# Calculate the bounding box around Mikea and convert to sf
cadre_autour_mikea <- st_bbox(mikea) %>%
  st_as_sfc() %>%
  st_sf()

# Switch to a projected CRS (Laborde)
proj_crs <- 29701
mikea_proj <- st_transform(mikea, proj_crs)
cadre_proj <- st_transform(cadre_autour_mikea, proj_crs)

# Cell size in the projected CRS
surface_cellule <- taille_hex * 1e+6
taille_cellule <- 2 * sqrt(surface_cellule / (3 * sqrt(3) / 2)) * sqrt(3) / 2

# Create the grid with the projected CRS
grille_mikea <- st_make_grid(x = cadre_proj,
                             cellsize = taille_cellule,
                             square = FALSE) %>%
  st_sf() %>%
  st_transform(4326)  # Transform back to WGS84

# Plot the grid and the protected area
plot(grille_mikea)

tmap_mode("view")
tm_shape(mikea) +
  tm_polygons(col = "darkgreen", alpha = 0.4) +
  tm_shape(grille_mikea) +
  tm_borders()
