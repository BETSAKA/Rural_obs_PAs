


# Rice variables ----------------------------------------------------------

process_production_riz_old <- function(path = "data/ROS_MDG_microdata/", 
                                       year) {
  stopifnot(year < 2011)
  message("Traitement année ", year)
  
  # Chargement des données de production (res_r.dta)
  df_riz <- read_dta(paste0(path, year, "/res_r.dta"))
  
  # Chargement des données de prix (res_dc21.dta), si disponible
  df_dc21 <- tryCatch(
    read_dta(paste0(path, year, "/res_dc21.dta")),
    error = function(e) NULL
  )
  
  # Création d'une variable production de riz (prod_riz)
  # Selon les années, les variables changent. On teste plusieurs combinaisons.
  df_riz <- df_riz %>% mutate(prod_riz = NA_real_)
  
  if (all(c("r23a", "r23b") %in% names(df_riz))) {
    # Cas classique : somme de r23a et r23b (en kg)
    df_riz <- df_riz %>% mutate(prod_riz = r23a + r23b)
  } else if ("r23" %in% names(df_riz)) {
    # Cas plus simple : toute la production dans une seule variable
    df_riz <- df_riz %>% mutate(prod_riz = r23)
  } else if (
    all(c("r23a1", "r23a2", "r23b1", "r23b2") %in% names(df_riz))
  ) {
    # Cas spécifique : sous-détails à additionner
    df_riz <- df_riz %>%
      mutate(prod_riz = r23a1 + r23a2 + r23b1 + r23b2)
  } else {
    message("Aucune variable de production disponible pour ", year)
  }
  
  # Agrégation : production totale par ménage (identifié par j5)
  df_prod <- df_riz %>%
    group_by(j5, year) %>%
    summarise(prod_riz = sum(prod_riz, na.rm = TRUE), .groups = "drop")
  
  #  Calcul du prix moyen observé du paddy (pxpaddy_obs)
  if (!is.null(df_dc21) && all(c("dc25", "dc22") %in% names(df_dc21))) {
    # Attention : certaines années (ex. 1997) utilisent probablement des FMG
    df_dc21 <- df_dc21 %>%
      mutate(
        pxpaddy_obs = if_else(dc22 > 0, dc25 / dc22, NA_real_)
      ) %>%
      group_by(j5, year) %>%
      summarise(
        pxpaddy_obs = mean(pxpaddy_obs, na.rm = TRUE),
        .groups = "drop"
      )
  } else {
    # Si pas de données prix, on met NA pour pxpaddy_obs
    message("Fichier ou variables de prix manquants pour ", year)
    df_dc21 <- df_prod %>%
      select(j5, year) %>%
      mutate(pxpaddy_obs = NA_real_)
  }
  
  # --- Fusion des données de production et de prix
  df <- left_join(df_prod, df_dc21, by = c("j5", "year")) %>%
    mutate(prod_riz_val = prod_riz * pxpaddy_obs)
  
  return(df)
}

process_rente_riz_old <- function(path = "data/ROS_MDG_microdata/", 
                                  year) {
  stopifnot(year < 2011)
  message("Traitement rente année ", year)
  
  # Chargement des fichiers
  df_r <- read_dta(paste0(path, year, "/res_r.dta"))
  
  # Chargement du fichier de prix si disponible
  df_dc21 <- tryCatch(
    read_dta(paste0(path, year, "/res_dc21.dta")),
    error = function(e) NULL
  )
  
  # Prix moyen observatoire
  if (!is.null(df_dc21) && all(c("dc25", "dc22") %in% names(df_dc21))) {
    df_px <- df_dc21 %>%
      mutate(pxpaddy_obs = if_else(dc22 > 0, dc25 / dc22, NA_real_)) %>%
      group_by(j5, year) %>%
      summarise(pxpaddy_obs = mean(pxpaddy_obs, na.rm = TRUE), 
                .groups = "drop")
  } else {
    df_px <- df_r %>%
      select(j5, year) %>%
      mutate(pxpaddy_obs = NA_real_)
  }
  
  # Calcul rente : en nature et monétaire
  df_rente <- df_r %>%
    mutate(
      r6_val = if_else(!is.na(r6), r6, 0),
      r7_val = if_else(!is.na(r7), r7, 0)
    ) %>%
    group_by(j5, year) %>%
    summarise(
      r6_total = sum(r6_val, na.rm = TRUE),
      r7_total = sum(r7_val, na.rm = TRUE),
      .groups = "drop"
    ) %>%
    left_join(df_px, by = c("j5", "year")) %>%
    mutate(
      rente_riz = r6_total * pxpaddy_obs + r7_total
    )
  
  return(df_rente)
}

process_cout_riz_old <- function(path = "data/ROS_MDG_microdata/", 
                                 year) {
  stopifnot(year < 2011)
  message("Traitement coûts année ", year)
  
  # Chargement du fichier principal sur le riz
  df_r <- read_dta(paste0(path, year, "/res_r.dta"))
  
  # Chargement conditionnel des fichiers auxiliaires
  df_mo1 <- tryCatch(
    read_dta(paste0(path, year, "/res_mo1.dta")),
    error = function(e) NULL
  )
  df_mo3 <- tryCatch(
    read_dta(paste0(path, year, "/res_mo3.dta")),
    error = function(e) NULL
  )
  df_ita <- tryCatch(
    read_dta(paste0(path, year, "/res_ita.dta")),
    error = function(e) NULL
  )
  df_dc21 <- tryCatch(
    read_dta(paste0(path, year, "/res_dc21.dta")),
    error = function(e) NULL
  )
  
  # ---------------------
  # Métayage : valorisation de r6 (en nature) et r7 (en argent)
  # ---------------------
  if (!is.null(df_dc21) && all(c("dc25", "dc22") %in% names(df_dc21))) {
    df_px <- df_dc21 %>%
      mutate(pxpaddy_obs = if_else(dc22 > 0, dc25 / dc22, NA_real_)) %>%
      group_by(j5, year) %>%
      summarise(pxpaddy_obs = mean(pxpaddy_obs, na.rm = TRUE),
                .groups = "drop")
  } else {
    df_px <- df_r %>%
      select(j5, year) %>%
      mutate(pxpaddy_obs = NA_real_)
  }
  
  df_coutmet <- df_r %>%
    mutate(
      r6_val = if_else(!is.na(r6), r6, 0),
      r7_val = if_else(!is.na(r7), r7, 0)
    ) %>%
    group_by(j5, year) %>%
    summarise(
      r6_total = sum(r6_val, na.rm = TRUE),
      r7_total = sum(r7_val, na.rm = TRUE),
      .groups = "drop"
    ) %>%
    left_join(df_px, by = c("j5", "year")) %>%
    mutate(cout_metayage = r6_total * pxpaddy_obs + r7_total)
  
  # ---------------------
  # Coût main-d'œuvre : mo11*, mo12, mo23 typiquement dans res_mo1
  # ---------------------
  mo_vars <- c("mo11d", "mo11e", "mo12", "mo23")
  df_mo1_cout <- if (!is.null(df_mo1)) {
    df_mo1 %>%
      mutate(across(all_of(mo_vars), ~replace_na(., 0))) %>%
      rowwise() %>%
      mutate(cout_mo = sum(c_across(all_of(mo_vars)), na.rm = TRUE)) %>%
      ungroup() %>%
      group_by(j5, year) %>%
      summarise(cout_mo = sum(cout_mo, na.rm = TRUE), .groups = "drop")
  } else {
    df_r %>% select(j5, year) %>% mutate(cout_mo = NA_real_)
  }
  
  # ---------------------
  # Coût intrants : typiquement variable ita2 dans res_ita.dta
  # ---------------------
  df_ita_cout <- if (!is.null(df_ita) && "ita2" %in% names(df_ita)) {
    df_ita %>%
      group_by(j5, year) %>%
      summarise(cout_intrants = sum(ita2, na.rm = TRUE), .groups = "drop")
  } else {
    df_r %>% select(j5, year) %>% mutate(cout_intrants = NA_real_)
  }
  
  # ---------------------
  # Fusion finale des trois composantes
  # ---------------------
  df <- reduce(
    list(df_coutmet, df_mo1_cout, df_ita_cout),
    full_join,
    by = c("j5", "year")
  ) %>%
    mutate(
      cout_total = cout_metayage + cout_mo + cout_intrants
    )
  
  return(df)
}

# Aggregating -------------------------------------------------------------


compute_total_income_old <- function(path = "data/ROS_MDG_microdata/", 
                                     year) {
  stopifnot(year < 2011)
  message("Calcul revenu total - année ", year)
  
  # Production de riz (valeur)
  df_prod <- process_production_riz_old(path = path, year = year)
  
  # Rente rizicole (revenus ou charges liés au métayage)
  df_rente <- process_rente_riz_old(path = path, year = year)
  
  # Coûts de production
  df_cout <- process_cout_riz_old(path = path, year = year)
  
  # Fusion des trois composantes riz
  df_riz <- reduce(
    list(df_prod, df_rente, df_cout),
    full_join,
    by = c("j5", "year")
  ) %>%
    mutate(
      recette_riz = prod_riz_val + rente_riz,
      charge_riz = cout_total,
      rev_riz = recette_riz - charge_riz
    )
  
  # Ajout ultérieur des autres sources de revenus
  # df_ppal <- process_revppal_old(...)     # activité principale
  # df_sec <- process_revsec_old(...)       # activités secondaires
  # df_transf <- process_transferts_old(...) # transferts et autres
  # df_agri <- process_autres_agri_old(...) # cultures hors riz, élevage
  
  # Fusion finale (à faire une fois les autres fonctions écrites)
  # df_final <- reduce(list(df_riz, df_ppal, df_sec, df_transf, df_agri), 
  #                    full_join, by = c("j5", "year"))
  
  return(df_riz)  # temporairement on ne retourne que la composante riz
}
