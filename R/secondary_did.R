# --------------------------------------------------------------------------
# Secondary DiD helpers — repeated cross-section household-level Callaway &
# Sant'Anna estimators used to corroborate the village-level gsynth results.
#
# Two designs per observatory:
#   * geographic: distance / bank cut (Alaotra: <=10 km; Marovoay: east bank)
#   * behavioural: 2025 extractive-use share above a threshold (~12.5%)
#
# The panel is built from household_consolidated (1999-2014) plus the 2025
# resurvey, with household equivalent income as outcome.
# --------------------------------------------------------------------------

# Bridge a numeric/character j4 fokontany label to a stable normalised name.
# Each observatory provides its own normaliser (see below).
build_secondary_bridge <- function(j0_code, normalise_fn,
                                   years = c(1999:2014, 2025)) {
  purrr::map_dfr(years, function(y) {
    f <- file.path("data/ROS_MDG_microdata", y, "res_deb.dta")
    if (!file.exists(f)) return(NULL)
    d <- tryCatch(haven::read_dta(f), error = function(e) NULL)
    if (is.null(d)) return(NULL)
    d |>
      dplyr::filter(j0 == j0_code) |>
      dplyr::transmute(
        year = as.integer(y),
        j5 = as.character(j5),
        site = normalise_fn(as.character(j4))
      )
  })
}

# Build a household-year panel of log equivalent income.
build_secondary_panel <- function(obs_code, j0_code, treat_year,
                                  normalise_fn, merge_map = NULL,
                                  household_consolidated,
                                  compute_income_year_fn) {
  bridge <- build_secondary_bridge(j0_code, normalise_fn)

  hist <- household_consolidated |>
    dplyr::filter(obs == obs_code, year <= 2014) |>
    dplyr::mutate(j5 = as.character(j5), year = as.integer(year)) |>
    dplyr::inner_join(bridge, by = c("year", "j5")) |>
    dplyr::transmute(year, j5, site, revtot, oecd_equiv)

  inc_25 <- compute_income_year_fn(2025) |>
    dplyr::transmute(j5 = as.character(j5), year = 2025L, revtot)

  oecd_25 <- haven::read_dta("data/ROS_MDG_microdata/2025/res_m_a.dta") |>
    dplyr::mutate(j5 = as.character(j5), age = as.numeric(m5)) |>
    dplyr::filter(!is.na(age)) |>
    dplyr::summarise(
      n_adults = sum(age >= 14),
      n_children = sum(age < 14),
      .by = j5
    ) |>
    dplyr::mutate(
      year = 2025L,
      oecd_equiv = 1 + 0.5 * pmax(n_adults - 1, 0) + 0.3 * n_children
    ) |>
    dplyr::select(j5, year, oecd_equiv)

  cur <- bridge |>
    dplyr::filter(year == 2025) |>
    dplyr::inner_join(inc_25, by = c("j5", "year")) |>
    dplyr::inner_join(oecd_25, by = c("j5", "year"))

  raw <- dplyr::bind_rows(hist, cur) |>
    dplyr::filter(!is.na(site)) |>
    dplyr::mutate(y_oecd = revtot / oecd_equiv) |>
    dplyr::filter(is.finite(y_oecd)) |>
    dplyr::mutate(
      y_oecd_w = winsorize(y_oecd, probs = c(0.01, 0.99)),
      ln_y = log(y_oecd_w + 1),
      post = as.integer(year >= treat_year)
    )

  if (!is.null(merge_map)) {
    raw <- raw |>
      dplyr::mutate(site = ifelse(site %in% names(merge_map),
                                  merge_map[site], site))
  }
  as.data.frame(raw)
}

# Compute 2025 extractive-use share by site (PA-dependent extractive
# practices, um2_a == 1 & um2_lig %in% 1:8). Returns a data frame with
# columns site, pct.
extractive_share_2025 <- function(j0_code, normalise_fn, merge_map = NULL) {
  res_deb <- haven::read_dta("data/ROS_MDG_microdata/2025/res_deb.dta") |>
    dplyr::mutate(j5 = as.character(j5)) |>
    dplyr::filter(j0 == j0_code) |>
    dplyr::mutate(site = normalise_fn(as.character(j4))) |>
    dplyr::filter(!is.na(site))

  um2 <- haven::read_dta("data/ROS_MDG_microdata/2025/res_um2.dta") |>
    dplyr::mutate(j5 = as.character(j5)) |>
    dplyr::inner_join(res_deb |> dplyr::select(j5, site), by = "j5")

  ext_hh <- um2 |>
    dplyr::filter(um2_a == 1, um2_lig %in% 1:8) |>
    dplyr::distinct(j5) |>
    dplyr::mutate(extractive = TRUE)

  out <- res_deb |>
    dplyr::left_join(ext_hh, by = "j5") |>
    dplyr::mutate(extractive = tidyr::replace_na(extractive, FALSE)) |>
    dplyr::group_by(site) |>
    dplyr::summarise(pct = 100 * mean(extractive), .groups = "drop")

  if (!is.null(merge_map)) {
    out <- out |>
      dplyr::mutate(site = ifelse(site %in% names(merge_map),
                                  merge_map[site], site)) |>
      dplyr::group_by(site) |>
      dplyr::summarise(pct = mean(pct), .groups = "drop")
  }
  out
}

# Fit Callaway-Sant'Anna with panel = FALSE, returning both clustered and
# IF-only standard errors. Uses Sant'Anna-Zhao DR moment internally.
fit_secondary_cs <- function(panel_df, gvar, cluster_var = "site",
                             biters = 1000L, seed = 20260424L) {
  panel_df$g <- panel_df[[gvar]]
  panel_df$id <- seq_len(nrow(panel_df))
  set.seed(seed)
  did::att_gt(
    yname = "ln_y",
    tname = "year",
    idname = "id",
    gname = "g",
    data = panel_df,
    control_group = "nevertreated",
    panel = FALSE,
    clustervars = cluster_var,
    bstrap = TRUE,
    biters = biters,
    cband = TRUE,
    base_period = "universal"
  )
}

# Compute pooled and dynamic aggregations and pack the whole thing into a
# tidy list keyed by design name. `designs` is a named list whose elements
# are the gvar names in the panel.
run_secondary_did <- function(panel_df, designs, biters = 1000L) {
  fits <- list()
  for (nm in names(designs)) {
    g <- designs[[nm]]
    fits[[paste0(nm, "_clus")]] <- fit_secondary_cs(panel_df, g,
                                                   cluster_var = "site",
                                                   biters = biters)
    # IF-only: did::att_gt requires clustervars; use NULL to drop clustering
    panel_df_loc <- panel_df
    panel_df_loc$g <- panel_df_loc[[g]]
    panel_df_loc$id <- seq_len(nrow(panel_df_loc))
    set.seed(20260424L)
    fits[[paste0(nm, "_nocl")]] <- did::att_gt(
      yname = "ln_y", tname = "year", idname = "id", gname = "g",
      data = panel_df_loc, control_group = "nevertreated", panel = FALSE,
      clustervars = NULL, bstrap = TRUE, biters = biters,
      cband = TRUE, base_period = "universal"
    )
  }
  simp <- purrr::map(fits, function(f) {
    tryCatch(did::aggte(f, type = "simple", na.rm = TRUE),
             error = function(e) NULL)
  })
  dyns <- purrr::map(fits, function(f) {
    tryCatch(did::aggte(f, type = "dynamic", na.rm = TRUE),
             error = function(e) NULL)
  })
  list(fits = fits, simp = simp, dyns = dyns)
}

# Build a one-row-per-design summary tibble for reporting.
secondary_summary <- function(res, designs) {
  purrr::map_dfr(names(designs), function(nm) {
    s_no <- res$simp[[paste0(nm, "_nocl")]]
    s_cl <- res$simp[[paste0(nm, "_clus")]]
    if (is.null(s_no) || is.null(s_cl)) return(NULL)
    tibble::tibble(
      design = nm,
      estimate = s_no$overall.att,
      se_if = s_no$overall.se,
      se_cluster = s_cl$overall.se,
      pct_income = (exp(s_no$overall.att) - 1) * 100
    )
  })
}
