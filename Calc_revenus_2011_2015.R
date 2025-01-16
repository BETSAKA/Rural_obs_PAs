# Compute expenses --------------------------------------------------------



# Libraries 
library(tidyverse)
library(haven)

# Process incomes from main activities
process_revppal <- function(path = "data/ROS_MDG_microdata/", year) {
  if(year > 2011) {
    read_dta(paste0(path, year, "/res_m_a.dta")) %>%
      mutate(across(c(a3b, a3c, a3e, a3f), ~ replace_na(.x, 0))) %>%
      mutate(revppal = ((a3c * a3b * 1000) + (a3e * a3f * 1000))) %>%
      group_by(j5, year) %>%
      summarise(revppal = sum(revppal, na.rm = TRUE))
  } else {
    read_dta(paste0(path, year, "/res_m_a.dta")) %>%
      mutate(across(c(a3b, a3c), ~ replace_na(.x, 0))) %>%
      mutate(revppal = a3c * a3b * 1000) %>%
      group_by(j5, year) %>%
      summarise(revppal = sum(revppal, na.rm = TRUE))
  }
}

# Process incomes from secondary activities
process_revsec <- function(path = "data/ROS_MDG_microdata/", year) {
  if (year > 2011) {
    read_dta(paste0(path, year, "/res_as.dta")) %>%
      mutate(across(c(as4, as3, as4a, as3a), ~ replace_na(.x, 0))) %>%
      mutate(revsec = (as3 * as4) + (as4a * as3a)) %>%
      group_by(j5, year) %>%
      summarise(revsec = sum(revsec, na.rm = TRUE))
  } else {
    read_dta(paste0(path, year, "/res_as.dta")) %>%
      mutate(across(c(as4, as3), ~ replace_na(.x, 0))) %>%
      mutate(revsec = as3 * as4) %>%
      group_by(j5, year) %>%
      summarise(revsec = sum(revsec, na.rm = TRUE))
  }
  
}

# Process incomes from other sources
process_rha <- function(path = "data/ROS_MDG_microdata/", year) {
  read_dta(paste0(path, year, "/res_rha.dta")) %>%
    mutate(rha2 = replace_na(rha2, 0)) %>%
    select(-rha1) %>%
    rename(autre_rev = rha2) %>%
    group_by(j5, year) %>%
    summarise(autre_rev = sum(autre_rev, na.rm = TRUE))
}

process_reven_exp <- function(path = "data/ROS_MDG_microdata/", year) {
  # Load the household to observatory mapping
  household_to_obs <- read_dta(paste0(path, year, "/res_deb.dta")) %>%
    select(j5, j0) %>%
    rename(obs = j0)
  
  # prod_riz
  prod_riz <- read_dta(paste0(path, year, "/res_r.dta")) %>%
    mutate(prod_riz = r23) %>%
    group_by(j5, year) %>%
    summarise(prod_riz = sum(prod_riz, na.rm = TRUE), .groups = "drop") %>%
    left_join(household_to_obs, by = "j5")
  
  # px_paddy_obs
  px_paddy_obs <- read_dta(paste0(path, year, "/res_dc21.dta")) %>%
    left_join(household_to_obs, by = "j5") %>%
    group_by(obs, year) %>%
    summarise(dc22 = sum(dc22, na.rm = TRUE), dc25 = sum(dc25, na.rm = TRUE), .groups = "drop") %>%
    mutate(pxpaddy_obs = dc25 / dc22) %>%
    select(obs, year, pxpaddy_obs)
  
  # prod_riz_val
  prod_riz_val <- prod_riz %>%
    left_join(px_paddy_obs, by = c("obs", "year")) %>%
    mutate(prod_riz_val = prod_riz * pxpaddy_obs) %>%
    select(j5, year, prod_riz_val)
  
  # rente_riz
  recmetloc <- read_dta(paste0(path, year, "/res_r.dta")) %>%
    mutate(recmetloc = r6 * (r4 == 5 | r4 == 6)) %>%
    group_by(j5, year) %>%
    summarise(recmetloc = sum(recmetloc, na.rm = TRUE), .groups = "drop") %>%
    left_join(household_to_obs, by = "j5") %>%
    left_join(px_paddy_obs, by = c("obs", "year")) %>%
    mutate(rente_riz1 = recmetloc * pxpaddy_obs) %>%
    select(j5, year, rente_riz1)
  
  rente_riz2 <- read_dta(paste0(path, year, "/res_r.dta")) %>%
    mutate(rente_riz2 = r7 * (r4 == 5 | r4 == 6)) %>%
    group_by(j5, year) %>%
    summarise(rente_riz2 = sum(rente_riz2, na.rm = TRUE), .groups = "drop")
  
  rente_riz <- recmetloc %>%
    left_join(rente_riz2, by = c("j5", "year")) %>%
    mutate(rente_riz = coalesce(rente_riz1, 0) + coalesce(rente_riz2, 0)) %>%
    select(j5, year, rente_riz)
  
  # rev_riz
  file_mo <- ifelse(year %in% c(2013, 2014), "/res_mo.dta", "/res_mo1.dta")
  coutmori <- read_dta(paste0(path, year, file_mo)) %>%
    mutate(across(c(mo11b, mo11c, mo11d, mo11e, mo51a, mo51b, mo12, mo51c, mo23), ~ replace_na(.x, 0))) %>%
    mutate(salarie = (mo11b * mo11d) + (mo11b * mo51a) + (mo11c * mo11e) + (mo11c * mo51b),
           tache = mo12 + mo51c,
           entraide = mo23,
           coutmori = salarie + tache + entraide) %>%
    group_by(j5, year) %>%
    summarise(coutmori = sum(coutmori, na.rm = TRUE), .groups = "drop")
  
  coutint <- read_dta(paste0(path, year, "/res_ita.dta")) %>%
    group_by(j5, year) %>%
    summarise(coutint = sum(ita2, na.rm = TRUE), .groups = "drop")
  
  coutmetloc1 <- read_dta(paste0(path, year, "/res_r.dta")) %>%
    mutate(rimetloc = r6 * (r4 == 2 | r4 == 3)) %>%
    group_by(j5, year) %>%
    summarise(rimetloc = sum(rimetloc, na.rm = TRUE), .groups = "drop") %>%
    left_join(household_to_obs, by = "j5") %>%
    left_join(px_paddy_obs, by = c("obs", "year")) %>%
    mutate(coutmetloc1 = rimetloc * pxpaddy_obs) %>%
    select(j5, year, coutmetloc1)
  
  coutmetloc2 <- read_dta(paste0(path, year, "/res_r.dta")) %>%
    mutate(coutmetloc2 = r7 * (r4 == 2 | r4 == 3)) %>%
    group_by(j5, year) %>%
    summarise(coutmetloc2 = sum(coutmetloc2, na.rm = TRUE), .groups = "drop")
  
  coutmetloc <- coutmetloc1 %>%
    left_join(coutmetloc2, by = c("j5", "year")) %>%
    mutate(coutmetloc = coalesce(coutmetloc1, 0) + coalesce(coutmetloc2, 0)) %>%
    select(j5, year, coutmetloc)
  
  rev_riz <- prod_riz_val %>%
    left_join(coutmori, by = c("j5", "year")) %>%
    left_join(coutint, by = c("j5", "year")) %>%
    left_join(coutmetloc, by = c("j5", "year")) %>%
    mutate(recette_riz = prod_riz_val,
           charge_riz = coutmori + coutint + coutmetloc,
           rev_riz = recette_riz - charge_riz) %>%
    select(j5, year, rev_riz)
  
  list(prod_riz_val = prod_riz_val, rente_riz = rente_riz, rev_riz = rev_riz)
}

# Combining income components
compute_total_income <- function(path = "data/ROS_MDG_microdata/", year) {
  revppal <- process_revppal(path, year)
  revsec <- process_revsec(path, year)
  autre_rev <- process_rha(path, year)
  rev_exp <- process_reven_exp(path, year)
  
  income_data <- revppal %>%
    left_join(revsec, by = c("j5", "year")) %>%
    left_join(autre_rev, by = c("j5", "year")) %>%
    left_join(rev_exp$prod_riz_val, by = c("j5", "year")) %>%
    left_join(rev_exp$rente_riz, by = c("j5", "year")) %>%
    left_join(rev_exp$rev_riz, by = c("j5", "year")) %>%
    mutate(revcou = coalesce(revppal, 0) + coalesce(revsec, 0) + coalesce(rev_riz, 0),
           revexcept = coalesce(rente_riz, 0) + coalesce(autre_rev, 0),
           revtot = revcou + revexcept) %>%
    select(j5, year, revtot)
  
  return(income_data)
}


total_income_2015 <- compute_total_income(year = 2015) 
total_income_2014 <- compute_total_income(year = 2014) 
total_income_2013 <- compute_total_income(year = 2013) 
total_income_2012 <- compute_total_income(year = 2012)
total_income_2011 <- compute_total_income(year = 2011)