# Helper functions for gsynth estimation
# Source after load_data.R

# -- Winsorize -----------------------------------------------------------------
winsorize <- function(x, probs = c(0.01, 0.99)) {
  q <- quantile(x, probs, na.rm = TRUE)
  pmin(pmax(x, q[1]), q[2])
}

# -- Income variable construction ----------------------------------------------
mk_income_ext <- function(df) {
  df |>
    mutate(
      rev_riz = coalesce(rev_riz, 0),
      rev_cu = coalesce(rev_cu, 0),
      revel = coalesce(revel, 0),
      revpeche = coalesce(revpeche, 0),
      revppal = coalesce(revppal, 0),
      revsec = coalesce(revsec, 0),
      revcou = coalesce(
        revcou,
        revppal + revsec + rev_riz + rev_cu + revel + revpeche
      ),
      revtot = coalesce(revtot, revcou),
      rev_agri = rev_riz + rev_cu + revel + revpeche,
      rev_nonagri = revppal + revsec
    )
}

# -- Save/load gsynth results (lightweight) ------------------------------------
save_gsynth <- function(fit) {
  list(
    att_avg = fit$att.avg,
    est_att = fit$est.att,
    est_avg = fit$est.avg,
    r_cv = fit$r.cv,
    N_tr = fit$Ntr,
    N_co = fit$Nco,
    eff = fit$eff
  )
}

# -- Prepare site-level panel for gsynth ---------------------------------------
prepare_gsynth_panel <- function(
  hh_data,
  treated_obs,
  treat_year,
  donor_obs = CLEAN_DONOR_OBS,
  outcome = "log_y_oecd"
) {
  hh_data |>
    filter(obs %in% c(treated_obs, donor_obs)) |>
    mk_income_ext() |>
    mutate(
      y_oecd = revtot / oecd_equiv,
      y_oecd_w = winsorize(y_oecd),
      log_y_oecd = log(y_oecd_w + 1)
    ) |>
    group_by(site_id, year) |>
    summarise(
      y = median(.data[[outcome]], na.rm = TRUE),
      n_hh = n(),
      .groups = "drop"
    ) |>
    mutate(
      treated = as.integer(
        substr(site_id, 1, 2) == treated_obs &
          year >= treat_year
      )
    )
}
