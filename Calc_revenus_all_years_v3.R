# Compute incomes  --------------------------------------------------------

# Cette collection de fonctions sert à calculer les revenus agrégés 
# à partir des données OR pour les années 2011 à 2015

# Libraries 
library(tidyverse)
library(haven)

# In Stata: 
# gen revcou = revppal + revsec + rev_riz + rev_cu + revel + revpeche
# gen decap = vte_par + vente_bovin + vente_beef + vte_equip
# gen revexcept = rente_riz + rente_cu + autre_rev + himo + decap + vte_biens + transrecmo + transrecnomo
# gen revtot = revcou + revexcept



# revppal OK-----------------------------------------------------------------

# Process incomes from main activities
process_revppal <- function(path = "data/ROS_MDG_microdata/", year) {
  # From 2012: number of weeks * week income (in cash and in kind)
  if(year > 2011) {
    read_dta(paste0(path, year, "/res_m_a.dta")) %>%
      mutate(across(c(a3b, a3c, a3e, a3f), ~ replace_na(.x, 0))) %>%
      mutate(revppal = ((a3c * a3b * 1000) + (a3e * a3f * 1000))) %>%
      group_by(j5, year) %>%
      summarise(revppal = sum(revppal, na.rm = TRUE))
    # Before 2012: only cash income
  } else if (year > 1997) {
    read_dta(paste0(path, year, "/res_m_a.dta")) %>%
      mutate(across(c(a3b, a3c), ~ replace_na(.x, 0))) %>%
      mutate(revppal = a3c * a3b * 1000) %>%
      group_by(j5, year) %>%
      summarise(revppal = sum(revppal, na.rm = TRUE))
    # in 1996 & 1997: the number of weeks is missing: we assume 52 (most cases in)
  } else if (year > 1995) {
    read_dta(paste0(path, year, "/res_m_a.dta")) %>%
      mutate(a3b = replace_na(a3b, 0)) %>%
      mutate(revppal = a3b * 52 * 1000) %>%
      group_by(j5, year) %>%
      summarise(revppal = sum(revppal, na.rm = TRUE), .groups = "drop")
    # Not available in 1995
  } else {
    return(tibble(j5 = character(), year = year, revppal = NA_real_))
  }
}


# revsec OK------------------------------------------------------------------

# Process incomes from secondary activities
process_revsec <- function(path = "data/ROS_MDG_microdata/", year) {
  # From 2011: income per culture in cash and in nature
  if (year > 2011) {
    read_dta(paste0(path, year, "/res_as.dta")) %>%
      mutate(across(c(as4, as3, as4a, as3a), ~ replace_na(.x, 0))) %>%
      mutate(revsec = (as3 * as4) + (as4a * as3a)) %>%
      group_by(j5, year) %>%
      summarise(revsec = sum(revsec, na.rm = TRUE))
    # Before 2012, only income in cash (duration * income per week)
    # but specific case in 2005
  } else if (year == 2005) {
    read_dta(paste0(path, year, "/res_as.dta")) %>%
      mutate(across(c(as4_1, as3_1), ~ replace_na(.x, 0))) %>%
      mutate(revsec = as3_1 * as4_1) %>%
      group_by(j5, year) %>%
      summarise(revsec = sum(revsec, na.rm = TRUE))
    # in 1996 : only income in cash, but month begin and month ends
  } else if (year > 1996) {
    read_dta(paste0(path, year, "/res_as.dta")) %>%
      mutate(as4 = as.numeric(as4), # As character in 2003
             across(c(as4, as3), ~ replace_na(.x, 0)),
             revsec = as3 * as4) %>%
      group_by(j5, year) %>%
      summarise(revsec = sum(revsec, na.rm = TRUE))
    # in 1996 : only income in cash, but month begin and month ends
  } else if (year == 1996) {
    read_dta(paste0(path, year, "/res_as.dta")) %>%
      mutate(across(c(as3b, as3c, as3d), ~ replace_na(.x, 0)),
      months = case_when(
        as3b == 0 ~ 0,
        as3d >= as3c ~ as3d - as3c + 1,
        as3d < as3c  ~ as3d - as3c + 13
      ),
      revsec = as3b * months * 1000
    ) %>%
      group_by(j5, year) %>%
      summarise(revsec = sum(revsec, na.rm = TRUE))
    # Value not available in 1995
  } else if (year == 1995) {
    return(tibble(j5 = character(), year = year, revsec = NA_real_))
  }
} 


# rev_riz -----------------------------------------------------------------

## prod_riz_val OK ----------------------------------------------------

process_prod_riz_val <- function(year, path = "data/ROS_MDG_microdata/") {
  stopifnot(year %in% 1995:2015)
  
  # Identifier j5 -> obs
  household_to_obs <- read_dta(paste0(path, year, "/res_deb.dta")) %>%
    transmute(j5, obs = j0)
  
  # Charger données de production
  df_r <- read_dta(paste0(path, year, "/res_r.dta"))
  
  # Charger données de prix
  df_dc21 <- read_dta(paste0(path, year, "/res_dc21.dta")) %>%
    left_join(household_to_obs, by = "j5")
  
  # Cas simple : r23 unique (1995–1996, 2009–2015)
  
  if (year %in% c(1995, 2009:2015)) {
    prod_riz <- df_r %>%
      mutate(prod_riz = r23) %>%
      group_by(j5, year) %>%
      summarise(prod_riz = sum(prod_riz, na.rm = TRUE), .groups = "drop") %>%
      left_join(household_to_obs, by = "j5")
    
    px_paddy_obs <- df_dc21 %>%
      group_by(obs, year) %>%
      summarise(
        dc22 = sum(dc22, na.rm = TRUE),
        dc25 = sum(dc25, na.rm = TRUE),
        .groups = "drop"
      ) %>%
      mutate(pxpaddy_obs = if_else(dc22 > 0, dc25 / dc22, NA_real_))
    
    prod_riz_val <- prod_riz %>%
      left_join(px_paddy_obs, by = c("obs", "year")) %>%
      mutate(prod_riz_val = prod_riz * pxpaddy_obs) %>%
      select(j5, year, prod_riz_val)
    
    return(prod_riz_val)
  } else if (year %in% 1996:2008) { # Cas complexe : r23a / r23b séparés (1997–2008)
    
    if (year == 2001) {
      # Production principale
      prod_riz_a <- df_r %>%
        transmute(j5, year, prod_riz_a = rowSums(across(c(r23a1, r23a2)), 
                                                 na.rm = TRUE)) %>%
        group_by(j5, year) %>%
        summarise(prod_riz_a = sum(prod_riz_a, na.rm = TRUE), .groups = "drop") %>%
        left_join(household_to_obs, by = "j5")
      # Production contre-saison
      prod_riz_b <- df_r %>%
        transmute(j5, year, prod_riz_b = rowSums(across(c(r23b1, r23b2)), 
                                                 na.rm = TRUE)) %>%
        group_by(j5, year) %>%
        summarise(prod_riz_b = sum(prod_riz_b, na.rm = TRUE), .groups = "drop") %>%
        left_join(household_to_obs, by = "j5")
    } else {
      # Production principale
      prod_riz_a <- df_r %>%
        transmute(j5, year, prod_riz_a = coalesce(r23a, 0)) %>%
        group_by(j5, year) %>%
        summarise(prod_riz_a = sum(prod_riz_a, na.rm = TRUE), .groups = "drop") %>%
        left_join(household_to_obs, by = "j5")
      
      # Production contre-saison
      prod_riz_b <- df_r %>%
        transmute(j5, year, prod_riz_b = coalesce(r23b, 0)) %>%
        group_by(j5, year) %>%
        summarise(prod_riz_b = sum(prod_riz_b, na.rm = TRUE), .groups = "drop") %>%
        left_join(household_to_obs, by = "j5")
    }
    # Prix moyen saison principale (mois ≠ 9:12)
    prix_a <- df_dc21 %>%
      filter(!dc21 %in% 9:12) %>%
      group_by(obs, year) %>%
      summarise(
        dc22a = sum(dc22, na.rm = TRUE),
        dc25a = sum(dc25, na.rm = TRUE),
        .groups = "drop"
      ) %>%
      mutate(pxpaddy_a = dc25a / dc22a,
             pxpaddy_a = if_else(year == 1997, pxpaddy_a * 1000, pxpaddy_a)) %>%
      select(obs, year, pxpaddy_a)
    
    # Prix moyen contre-saison (mois 9:12)
    prix_b <- df_dc21 %>%
      filter(dc21 %in% 9:12) %>%
      group_by(obs, year) %>%
      summarise(
        dc22b = sum(dc22, na.rm = TRUE),
        dc25b = sum(dc25, na.rm = TRUE),
        .groups = "drop"
      ) %>%
      mutate(pxpaddy_b = dc25b / dc22b,
             pxpaddy_b = if_else(year == 1997, pxpaddy_b * 1000, pxpaddy_b)) %>%
      select(obs, year, pxpaddy_b)
    
    # Valorisation
    prod_riz_val <- full_join(prod_riz_a, prod_riz_b, by = c("j5", "year", "obs")) %>%
      left_join(prix_a, by = c("obs", "year")) %>%
      left_join(prix_b, by = c("obs", "year")) %>%
      mutate(
        prod_riz_a = replace_na(prod_riz_a, 0),
        prod_riz_b = replace_na(prod_riz_b, 0),
        pxpaddy_a = replace_na(pxpaddy_a, 0),
        pxpaddy_b = replace_na(pxpaddy_b, 0),
        prod_riz_val = prod_riz_a * pxpaddy_a + prod_riz_b * pxpaddy_b
      ) %>%
      select(j5, year, prod_riz_val)
    
    return(prod_riz_val)
  }
  
  stop("Année non prise en charge.")
}



## rente_riz ------------------
process_rente_riz <- function(year, path = "data/ROS_MDG_microdata/") {
  stopifnot(year %in% 1995:2015)
  
  # Correspondance j5 → obs
  household_to_obs <- read_dta(paste0(path, year, "/res_deb.dta")) %>%
    transmute(j5, obs = j0)
  
  # Lecture fichier r
  df_r <- read_dta(paste0(path, year, "/res_r.dta"))
  
  # Vérification des variables critiques
  if (!all(c("r4", "r6", "r7") %in% names(df_r))) {
    return(tibble(j5 = character(), year = year, rente_riz = NA_real_))
  }
  
  df_r <- df_r %>%
    mutate(
      recmetloc = r6 * (r4 %in% c(5, 6)),
      rente_riz2 = r7 * (r4 %in% c(5, 6))
    )
  
  # Agrégation nature (r6)
  recmetloc <- df_r %>%
    group_by(j5, year) %>%
    summarise(recmetloc = sum(recmetloc, na.rm = TRUE), .groups = "drop") %>%
    left_join(household_to_obs, by = "j5")
  
  # Agrégation monétaire (r7)
  rente_riz2 <- df_r %>%
    group_by(j5, year) %>%
    summarise(rente_riz2 = sum(rente_riz2, na.rm = TRUE), .groups = "drop")
  
  # Prix observatoire (pxpaddy_obs)
  px_file <- paste0(path, year, "/res_dc21.dta")
  px_paddy_obs <- if (file.exists(px_file)) {
    read_dta(px_file) %>%
      left_join(household_to_obs, by = "j5") %>%
      group_by(obs, year) %>%
      summarise(
        dc22 = sum(dc22, na.rm = TRUE),
        dc25 = sum(dc25, na.rm = TRUE),
        .groups = "drop"
      ) %>%
      mutate(
        pxpaddy_obs = dc25 / dc22,
        pxpaddy_obs = if_else(year == 1997, pxpaddy_obs * 1000, pxpaddy_obs)
      ) %>%
      select(obs, year, pxpaddy_obs)
  } else {
    household_to_obs %>%
      distinct(obs) %>%
      mutate(year = year, pxpaddy_obs = NA_real_)
  }
  
  # Valorisation de la rente en nature
  recmetloc_val <- recmetloc %>%
    left_join(px_paddy_obs, by = c("obs", "year")) %>%
    mutate(rente_riz1 = recmetloc * pxpaddy_obs) %>%
    select(j5, year, rente_riz1)
  
  # Rente totale
  rente_riz <- recmetloc_val %>%
    left_join(rente_riz2, by = c("j5", "year")) %>%
    mutate(
      rente_riz = coalesce(rente_riz1, 0) + coalesce(rente_riz2, 0)
    ) %>%
    select(j5, year, rente_riz)
  
  return(rente_riz)
}


## charge_riz ----------------------------------

process_charge_riz <- function(year, path = "data/ROS_MDG_microdata/") {
  message("Traitement des charges riz - année ", year)
  
  # Correspondance ménage-observatoire
  household_to_obs <- read_dta(paste0(path, year, "/res_deb.dta")) %>%
    select(j5, obs = j0) %>%
    distinct() # Household 	012173 duplicated in 1995
  
  # Prix du paddy observé (px_paddy_obs)
  px_paddy_obs <- read_dta(paste0(path, year, "/res_dc21.dta")) %>%
    left_join(household_to_obs, by = "j5") %>%
    group_by(obs, year) %>%
    summarise(
      dc22 = sum(dc22, na.rm = TRUE),
      dc25 = sum(dc25, na.rm = TRUE),
      .groups = "drop"
    ) %>%
    mutate(pxpaddy_obs = dc25 / dc22, # prix / 1000 en 1997
           pxpaddy_obs = if_else(year == 1997, pxpaddy_obs * 1000, 
                                 pxpaddy_obs)) %>%
    select(obs, year, pxpaddy_obs)
  
  # Main d'œuvre non permanente
  file_mo <- case_when(
    year == 1995 ~ "/res_mo3.dta",
    year %in% c(2013, 2014) ~ "/res_mo.dta",
    TRUE ~ "/res_mo1.dta"
  )
  df <- read_dta(paste0(path, year, file_mo)) 
  
  main_oeuvre <- if (year == 1995) {
    required <- c("j5", "mo31f", "wg", "moc")
    if (!all(required %in% names(df))) 
      stop("Missing variables in 1995 for coutmori")
    
    df %>%
      filter(moc == 1) %>%
      mutate(across(c(mo31f, wg), ~replace_na(.x, 0))) %>%
      mutate(
        salarie = mo31f,
        entraide = wg,
        coutmori = salarie + entraide
      ) %>%
      group_by(j5, year) %>%
      summarise(coutmori = sum(coutmori, na.rm = TRUE), .groups = "drop")
    
  } else if (year == 1996) {
    required <- c("j5", "w1b", "w1c", "w1d", "w1e", "w2b", "w2c", "w2d", 
                  "w2e", "w3a", "w3b")
    if (!all(required %in% names(df))) 
      stop("Missing variables in 1996 for coutmori")
    
    df %>%
      mutate(across(all_of(required[-1]), ~replace_na(.x, 0))) %>%
      mutate(
        salarie = w1b * w1c * w1d + w1b * w1c * w1e,
        tache   = w2b * w2c * w2d + w2b * w2c * w2e,
        entraide = w3a + w3b,
        coutmori = salarie + tache + entraide
      ) %>%
      group_by(j5, year) %>%
      summarise(coutmori = sum(coutmori, na.rm = TRUE), .groups = "drop")
    
  } else if (year == 1997) {
    required <- c("j5", "mo11b", "mo11c", "mo11d", "mo11d2", "mo11e", "mo11e2",
                  "mo12", "mo12b", "mo23", "mo24")
    if (!all(required %in% names(df))) 
      stop("Missing variables in 1997 for coutmori")
    
    df %>%
      mutate(across(all_of(required[-1]), ~replace_na(.x, 0))) %>%
      mutate( # manque : mo11f mo11g mo11h
        salarie = mo11b * mo11d + mo11b * mo11d2 + #pour les hommes
          mo11c * mo11e + mo11c * mo11e2, # pour les femmes
        tache = mo12 + mo12b,
        entraide = mo23 + mo24,
        coutmori = salarie + tache + entraide
      ) %>%
      group_by(j5, year) %>%
      summarise(coutmori = sum(coutmori, na.rm = TRUE), .groups = "drop")
    
  } else if (year >= 1998 && year <= 2008) {
    required <- c("j5", "mo11c", "mo11e", "mo12", "mo23")
    if (!all(required %in% names(df))) 
      stop("Missing variables 1998–2008 for coutmocu")
    
    df %>%
      mutate(across(all_of(required[-1]), ~replace_na(.x, 0))) %>%
      mutate(
        salarie = mo11c * mo11e,
        tache = mo12,
        entraide = mo23,
        coutmori = salarie + tache + entraide
      ) %>%
      group_by(j5, year) %>%
      summarise(coutmori = sum(coutmori, na.rm = TRUE), .groups = "drop")
    
  } else {
    required <- c("j5", "mo11b", "mo11c", "mo11e", "mo51a", "mo51b", "mo12", 
                  "mo51c", "mo23", "mo11d")
    if (!all(required %in% names(df))) 
      stop("Missing variables post-2008 for coutmocu")
    
    df %>%
      mutate(across(all_of(required[-1]), ~replace_na(.x, 0))) %>%
      mutate(
        salarie = mo11b * mo11d + mo11b * mo51a + mo11c * mo11e + mo11c * mo51b,
        tache = mo12 + mo51c,
        entraide = mo23,
        coutmori = salarie + tache + entraide
      ) %>%
      group_by(j5, year) %>%
      summarise(coutmori = sum(coutmori, na.rm = TRUE), .groups = "drop")
  }

  # Intrants (pas disponible en 1995)
  coutint <- tryCatch({
    read_dta(paste0(path, year, "/res_itb.dta")) %>%
      group_by(j5, year) %>%
      summarise(coutint = sum(ita2, na.rm = TRUE), .groups = "drop")
  }, error = function(e) tibble(j5 = character(), year = year, 
                                coutint = NA_real_))

  # Métayage/location
  coutmetloc <- tryCatch({
    df_r <- read_dta(paste0(path, year, "/res_r.dta"))
    
    coutmetloc1 <- df_r %>%
      mutate(rimetloc = r6 * (r4 == 2 | r4 == 3)) %>%
      group_by(j5, year) %>%
      summarise(rimetloc = sum(rimetloc, na.rm = TRUE), .groups = "drop") %>%
      left_join(household_to_obs, by = "j5") %>%
      left_join(px_paddy_obs, by = c("obs", "year")) %>%
      mutate(coutmetloc1 = rimetloc * pxpaddy_obs) %>%
      select(j5, year, coutmetloc1)
    
    coutmetloc2 <- df_r %>%
      mutate(coutmetloc2 = r7 * (r4 == 2 | r4 == 3)) %>%
      group_by(j5, year) %>%
      summarise(coutmetloc2 = sum(coutmetloc2, na.rm = TRUE), .groups = "drop")
    
    coutmetloc1 %>%
      left_join(coutmetloc2, by = c("j5", "year")) %>%
      mutate(coutmetloc = coalesce(coutmetloc1, 0) + coalesce(coutmetloc2, 0)) %>%
      select(j5, year, coutmetloc)
  }, error = function(e) tibble(j5 = character(), year = year, coutmetloc = NA_real_))
  
  # Agrégation finale
  df <- reduce(
    list(main_oeuvre, coutint, coutmetloc),
    full_join, by = c("j5", "year")
  ) %>%
    mutate(
      charge_riz = rowSums(across(starts_with("cout"), ~ replace_na(.x, 0)))
    ) %>%
    select(j5, year, charge_riz)
  
  return(df)
}

## wrapper

process_rev_riz <- function(year, path = "data/ROS_MDG_microdata/") {
  message("Traitement revenu riz - année ", year)
  
  # Valeur de production
  prod_riz_val <- process_prod_riz_val(year, path)
  
  # Rente en nature et monétaire
  rente_riz <- process_rente_riz(year, path)
  
  # Charges (main-d'œuvre, intrants, métayage)
  charge_riz <- process_charge_riz(year, path)
  
  # Revenu net = production - charges
  rev_riz <- prod_riz_val %>%
    left_join(charge_riz, by = c("j5", "year")) %>%
    mutate(
      recette_riz = prod_riz_val,
      charge_riz = replace_na(charge_riz, 0),
      rev_riz = recette_riz - charge_riz
    ) %>%
    select(j5, year, rev_riz)
  
  return(rev_riz)
}


# rev_cu ------------------------------------------------------------------


## prodcu_val ----------------------------------------

process_prodcu_val <- function(path = "data/ROS_MDG_microdata/", year) {
  # Définition des données de base selon l'année
  if (year == 1995) {
    df <- read_dta(paste0(path, year, "/res_c.dta"))
    
    prix_cu <- df %>%
      mutate(
        obs = substr(j5, 1, 2),
        cult = c1,
        prix_cu = if_else(c4 > 0, c6a, NA_real_)
      ) %>%
      group_by(cult, obs, year) %>%
      summarise(prix_cu = mean(prix_cu, na.rm = TRUE), .groups = "drop")
    
    prodcu_val <- df %>%
      mutate(
        obs = substr(j5, 1, 2),
        cult = c1,
        qte = c2
      ) %>%
      group_by(j5, cult, obs, year) %>%
      summarise(qte = sum(qte, na.rm = TRUE), .groups = "drop") %>%
      left_join(prix_cu, by = c("cult", "obs", "year")) %>%
      mutate(prodcu_val = qte * prix_cu) %>%
      group_by(j5, year) %>%
      summarise(prodcu_val = sum(prodcu_val, na.rm = TRUE), .groups = "drop")
    
  } else if (year == 1996) {
    df <- read_dta(paste0(path, year, "/res_c19.dta"))
    
    prix_cu <- df %>%
      mutate(
        obs = substr(j5, 1, 2),
        cult = c20,
        prix_cu = if_else(c22 > 0, c24 / c22, NA_real_)
      ) %>%
      group_by(cult, obs, year) %>%
      summarise(prix_cu = mean(prix_cu, na.rm = TRUE), .groups = "drop")
    
    prodcu_val <- df %>%
      mutate(
        obs = substr(j5, 1, 2),
        cult = c20,
        qte = c21
      ) %>%
      group_by(j5, cult, obs, year) %>%
      summarise(qte = sum(qte, na.rm = TRUE), .groups = "drop") %>%
      left_join(prix_cu, by = c("cult", "obs", "year")) %>%
      mutate(prodcu_val = qte * prix_cu) %>%
      group_by(j5, year) %>%
      summarise(prodcu_val = sum(prodcu_val, na.rm = TRUE), .groups = "drop")
    
  } else {
    df <- read_dta(paste0(path, year, "/res_c.dta"))
    
    prix_cu <- df %>%
      mutate(
        obs = substr(j5, 1, 2),
        cult = if ("c37" %in% names(.)) paste0(c1, c37) else c1,
        c6b = if (!"c6b" %in% names(.)) c4 * c6a else c6b
      ) %>%
      group_by(cult, obs, year) %>%
      summarise(c4 = sum(c4, na.rm = TRUE),
                c6b = sum(c6b, na.rm = TRUE), .groups = "drop") %>%
      mutate(prix_cu = if_else(c4 > 0, c6b / c4, NA_real_)) %>%
      select(cult, obs, year, prix_cu)
    
    prodcu_val <- df %>%
      mutate(
        obs = substr(j5, 1, 2),
        cult = if ("c37" %in% names(.)) paste0(c1, c37) else c1,
        qte = c2
      ) %>%
      group_by(j5, cult, obs, year) %>%
      summarise(qte = sum(qte, na.rm = TRUE), .groups = "drop") %>%
      left_join(prix_cu, by = c("cult", "obs", "year")) %>%
      mutate(prodcu_val = qte * prix_cu) %>%
      group_by(j5, year) %>%
      summarise(prodcu_val = sum(prodcu_val, na.rm = TRUE), .groups = "drop")
  }
  
  return(prodcu_val)
}

## coutmocu ---------------------------------------------------

process_coutmocu <- function(path = "data/ROS_MDG_microdata/", year) {
  file <- paste0(path, year, "/res_mo3.dta")
  if (!file.exists(file)) stop("Fichier manquant : ", file)
  
  df <- haven::read_dta(file) %>% mutate(year = year)
  
  if (year == 1995) {
    required <- c("j5", "mo31f", "wg", "moc")
    stopifnot(all(required %in% names(df)))
    
    df %>%
      filter(moc != 1) %>%  # exclut le riz
      mutate(across(c(mo31f, wg), ~replace_na(.x, 0))) %>%
      mutate(
        salarie = mo31f,
        entraide = wg,
        coutmocu = salarie + entraide
      ) %>%
      group_by(j5, year) %>%
      summarise(coutmocu = sum(coutmocu, na.rm = TRUE), .groups = "drop")
    
  } else if (year == 1996) {
    required <- c("j5", "w4b", "w4c", "w4d", "w4e", "w5b", "w5c", "w5d", 
                  "w5e", "w6a", "w6b")
    stopifnot(all(required %in% names(df)))
    
    df %>%
      mutate(across(required[-1], ~replace_na(.x, 0))) %>%
      mutate(
        salarie = w4b * w4c * w4d + w4b * w4c * w4e,
        tache   = w5b * w5c * w5d + w5b * w5c * w5e,
        entraide = w6a + w6b,
        coutmocu = salarie + tache + entraide
      ) %>%
      group_by(j5, year) %>%
      summarise(coutmocu = sum(coutmocu, na.rm = TRUE), .groups = "drop")
    
  } else if (year == 1997) {
    required_base <- c("j5", "mo31c", "mo31e", "mo31f", "mo31d", "mo31g", "mo31h", "mo44", "mo45")
    optional <- c("mo32a", "mo32b")
    stopifnot(all(required_base %in% names(df)))
    
    df <- df %>%
      mutate(across(all_of(required_base[-1]), ~replace_na(as.numeric(.x), 0)))
    
    # Crée les variables mo32a et mo32b à 0 si elles sont absentes
    for (v in optional) {
      if (!v %in% names(df)) df[[v]] <- 0
    }
    
    df %>%
      mutate(
        salarie = mo31c * mo31e + mo31c * mo31f + mo31d * mo31g + mo31d * mo31h,
        tache   = mo32a + mo32b,
        entraide = mo44 + mo45,
        coutmocu = salarie + tache + entraide
      ) %>%
      group_by(j5, year) %>%
      summarise(coutmocu = sum(coutmocu, na.rm = TRUE), .groups = "drop")
    
  } else if (year >= 1998 && year <= 2008) {
    required <- c("j5", "mo31c", "mo31e", "mo32", "mo44")
    stopifnot(all(required %in% names(df)))
    
    df %>%
      mutate(across(required[-1], ~replace_na(as.numeric(.x), 0))) %>%
      mutate(
        salarie = mo31c * mo31e,
        tache = mo32,
        entraide = mo44,
        coutmocu = salarie + tache + entraide
      ) %>%
      group_by(j5, year) %>%
      summarise(coutmocu = sum(coutmocu, na.rm = TRUE), .groups = "drop")
    
  } else {
    required <- c("j5", "mo31c", "mo31e", "mo61a", "mo32", "mo61c", "mo44")
    stopifnot(all(required %in% names(df)))
    
    df %>%
      mutate(across(required[-1], ~replace_na(.x, 0))) %>%
      mutate(
        salarie = mo31c * mo31e + mo31c * mo61a,
        tache = mo32 + mo61c,
        entraide = mo44,
        coutmocu = salarie + tache + entraide
      ) %>%
      group_by(j5, year) %>%
      summarise(coutmocu = sum(coutmocu, na.rm = TRUE), .groups = "drop")
  }
}


## coutintcu -------------------------------------------------

process_coutintcu <- function(path = "data/ROS_MDG_microdata/", year) {
  if (year == 1995) return(NULL)  # pas de données en 1995
  
  file <- paste0(path, year, "/res_itb.dta")
  if (!file.exists(file)) stop("Fichier manquant : ", file)
  
  df <- haven::read_dta(file) %>%
    mutate(year = year)
  
  if (year == 2004 && "itb2" %in% names(df)) {
    df <- df %>% rename(itb5 = itb2)
  }
  
  if (!"itb5" %in% names(df)) stop("Variable 'itb5' absente pour l'année ", year)
  
  df %>%
    rename(coutintcu = itb5) %>%
    mutate(coutintcu = replace_na(as.numeric(coutintcu), 0)) %>%
    group_by(j5, year) %>%
    summarise(coutintcu = sum(coutintcu, na.rm = TRUE), .groups = "drop")
}


## coutloccu -------------------------------------------------

process_coutloccu <- function(path = "data/ROS_MDG_microdata/", year) {
  if (year == 1995) {
    return(NULL)
  }
  
  if (year == 1996) {
    df <- read_dta(paste0(path, year, "/res_c1.dta"))
    
    df <- df %>%
      mutate(
        obs = substr(j5, 1, 2),
        # c4 == 2 : argent, on récupère c7
        coutloccu = if_else(c4 == 2, c7, 0)
      ) %>%
      group_by(j5, year) %>%
      summarise(coutloccu = sum(coutloccu, na.rm = TRUE), .groups = "drop")
    
    return(df)
  }
  
  # Années > 1996 : version standard avec c3a (nature) et c3b (argent)
  df <- read_dta(paste0(path, year, "/res_c.dta")) %>%
    mutate(
      obs = substr(j5, 1, 2),
      cult = if ("c37" %in% names(.)) paste0(c1, c37) else c1
    )
  
  if (!"c6b" %in% names(df) && all(c("c4", "c6a") %in% names(df))) {
    df <- df %>% mutate(c6b = c4 * c6a)
  }
  
  prix_cu <- df %>%
    group_by(cult, obs, year) %>%
    summarise(
      c4 = sum(c4, na.rm = TRUE),
      c6b = sum(c6b, na.rm = TRUE),
      .groups = "drop"
    ) %>%
    mutate(prix_cu = if_else(c4 > 0, c6b / c4, NA_real_)) %>%
    select(cult, obs, year, prix_cu)
  
  # Nature
  coutloccu1 <- df %>%
    group_by(j5, cult, obs, year) %>%
    summarise(cumetloc = sum(c3a, na.rm = TRUE), .groups = "drop") %>%
    left_join(prix_cu, by = c("cult", "obs", "year")) %>%
    mutate(coutloccu1 = cumetloc * prix_cu) %>%
    group_by(j5, year) %>%
    summarise(coutloccu1 = sum(coutloccu1, na.rm = TRUE), .groups = "drop")
  
  # Argent
  coutloccu2 <- df %>%
    group_by(j5, year) %>%
    summarise(coutloccu2 = sum(c3b, na.rm = TRUE), .groups = "drop")
  
  # Total
  full <- full_join(coutloccu1, coutloccu2, by = c("j5", "year")) %>%
    mutate(coutloccu = replace_na(coutloccu1, 0) + replace_na(coutloccu2, 0)) %>%
    select(j5, year, coutloccu)
  
  return(full)
}


process_rev_cu <- function(path = "data/ROS_MDG_microdata/", year) {
  
  prod <- process_prodcu_val(path, year)
  coutmo <- process_coutmocu(path, year)
  
  if (year == 1995) {
    # Pas de coutint ni coutloc en 1995
    full <- prod %>%
      full_join(coutmo, by = c("j5", "year")) %>%
      mutate(across(c(prodcu_val, coutmocu), ~replace_na(., 0))) %>%
      mutate(rev_cu = prodcu_val - coutmocu) %>%
      select(j5, year, rev_cu)
  } else {
    coutint <- process_coutintcu(path, year)
    coutloc <- process_coutloccu(path, year)
    
    # Fonction pour créer un tibble vide avec colonnes données si NULL
    ensure_tbl <- function(df, cols) {
      if (is.null(df)) {
        df <- tibble(!!!rlang::set_names(rep(list(NA), length(cols)), 
                                         names(cols)))
        df[] <- Map(function(x, t) vector(typeof(t), 0), df, cols)
      }
      df
    }
    
    # Colonnes attendues pour chaque composante
    coutint <- ensure_tbl(coutint, c(j5 = "", year = 0L, coutintcu = 0))
    coutloc <- ensure_tbl(coutloc, c(j5 = "", year = 0L, coutloccu = 0))
    
    full <- prod %>%
      full_join(coutmo, by = c("j5", "year")) %>%
      full_join(coutint, by = c("j5", "year")) %>%
      full_join(coutloc, by = c("j5", "year")) %>%
      mutate(across(c(prodcu_val, coutmocu, coutintcu, coutloccu), 
                    ~replace_na(., 0))) %>%
      mutate(rev_cu = prodcu_val - coutmocu - coutintcu - coutloccu) %>%
      select(j5, year, rev_cu)
  }
  
  return(full)
}


# revel -------------------------------------------------------------------


# revpeche ----------------------------------------------------------------


# vte_par -----------------------------------------------------------------


# vente_bovin -------------------------------------------------------------


# vente_beef  -------------------------------------------------------------


# vte_equip ---------------------------------------------------------------


# rente_riz ---------------------------------------------------------------


# rente_cu ----------------------------------------------------------------


# autre_rev  --------------------------------------------------------------


# himo --------------------------------------------------------------------


# decap -------------------------------------------------------------------


# vte_biens ---------------------------------------------------------------


# transrecmo  -------------------------------------------------------------


# transrecnomo ------------------------------------------------------------

