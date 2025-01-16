library(tidyverse)
library(tmap)
library(sf)
library(mapme.biodiversity)
library(geodata)

# Function to generate the grid and map for a given PA name
generate_pa_map_simple <- function(ap_data, pa_name, taille_hex = 1, proj_crs = 32738) {
  # Filter for the specified protected area
  pa <- ap_data %>%
    filter(nom == !!pa_name)
  
  # Calculate the bounding box around the PA and convert to sf
  cadre_autour_pa <- st_bbox(pa) %>%
    st_as_sfc() %>%
    st_sf()
  
  # Transform to the projected CRS
  pa_proj <- st_transform(pa, proj_crs)
  cadre_proj <- st_transform(cadre_autour_pa, proj_crs)
  
  # Calculate the cell size in the projected CRS
  surface_cellule <- taille_hex * 1e+6
  taille_cellule <- 2 * sqrt(surface_cellule / (3 * sqrt(3) / 2)) * sqrt(3) / 2
  
  # Create the grid with the projected CRS
  grille_pa <- st_make_grid(x = cadre_proj,
                            cellsize = taille_cellule,
                            square = FALSE) %>%
    st_sf() %>%
    st_transform(4326)  # Transform back to WGS84
  
  # Generate the map
  tm_shape(pa) +
    tm_polygons(col = "darkgreen", alpha = 0.4) +
    tm_shape(grille_pa) +
    tm_borders(col = "black") +
    tm_layout(frame = FALSE)
}

# Load and transform the shapefile to WGS84
ap <- st_read("data/Vahatra/Shapefiles/AP_Vahatra.shp") %>%
  st_transform(4326)

# Generate the map for Mikea PA
map_mikea <- generate_pa_map_simple(ap_data = ap, pa_name = "Mikea")

# Generate the map for Ambatotsirongorongo PA
map_ambatotsirongorongo <- generate_pa_map_simple(ap_data = ap, pa_name = "Ambatotsirongorongo")

# Display the maps
tmap_arrange(map_mikea, map_ambatotsirongorongo)
