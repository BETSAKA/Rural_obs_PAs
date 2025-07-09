library(tidyverse)    # A series of packages for data manipulation
library(haven)        # Required for reading STATA files (.dta)
library(labelled)     # To work with labelled data from STATA
library(writexl)      # Write data frames to Excel format
library(readxl)

ros_data_loc <- "data/ROS_MDG_microdata/"

# Function to extract variable info for a given year and file
extract_variable_info <- function(year, file) {
  
  file_path <- paste0(ros_data_loc, year, "/", file)
  
  if (!file.exists(file_path)) return(tibble())
  
  data <- read_dta(file_path, n_max = 0)
  
  tibble(
    file_name = file,
    variable_name = names(data),
    variable_label = var_label(data) %>% as.character(),
    year = year)
}

# Obtain all years from the directory structure
years <- 1996

# Use the tidyverse approach to map over years and files
all_vars <- map_df(years, ~{
  files_for_year <- list.files(paste0(ros_data_loc, .x), pattern = "\\.dta$", full.names = FALSE)
  map_df(files_for_year, extract_variable_info, year = .x)
})

# Convert any NULL values in variable_label to "NA"
all_vars$variable_label[is.na(all_vars$variable_label)] <- "NA"


# Consolidate the information using the tidyverse approach
variable_dictionary <- all_vars %>%
  group_by(file_name, variable_name) %>%
  arrange(year) %>%  
  summarise(
    variable_label = first(variable_label[variable_label != "NA"] %||% "NA"),
    years_present = list(unique(year))) %>%
  ungroup() %>%
  mutate(years_present = map_chr(years_present, ~ paste(.x, collapse = ","))) %>%
  arrange(substr(years_present, 1, 4), # To have 1st variables of 1995
          case_when(file_name == "res_deb.dta" ~ as.integer(1),
                    file_name == "res_h.dta" ~ as.integer(2),
                    TRUE ~ as.integer(3))) # starts with hh ID and housing

# Write the variable dictionary to an Excel file
write_xlsx(variable_dictionary, "output/ROS_Variable_Dictionary_1996.xlsx")