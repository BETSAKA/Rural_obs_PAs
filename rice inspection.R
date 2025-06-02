# Libraries
library(tidyverse)
library(haven)
library(labelled)

# Function to summarize the structure of rice-related datasets
inspect_rice_subsection <- function(path, year) {
  cat("\n--- Inspecting Year:", year, "---\n")
  
  # Rice production dataset
  cat("\nStructure of res_r.dta (Rice Production):\n")
  tryCatch({
    rice_production <- read_dta(paste0(path, year, "/res_r.dta"))
    cat("Variables:", names(rice_production), "\n")
    cat("Labels:", var_label(rice_production), "\n")
  }, error = function(e) cat("Error:", e$message, "\n"))
  
  # Paddy price dataset
  cat("\nStructure of res_dc21.dta (Paddy Price):\n")
  tryCatch({
    paddy_price <- read_dta(paste0(path, year, "/res_dc21.dta"))
    cat("Variables:", names(paddy_price), "\n")
    cat("Labels:", var_label(paddy_price), "\n")
  }, error = function(e) cat("Error:", e$message, "\n"))
}

# Inspect datasets for 2011 to 2015
path <- "data/ROS_MDG_microdata/"
for (year in 2011:2015) {
  inspect_rice_subsection(path, year)
}

# Inspect datasets for earlier years (e.g., 2001-2010)
for (year in 2001:2010) {
  inspect_rice_subsection(path, year)
}