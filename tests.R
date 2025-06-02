inspect_inputs_couts <- function(year, path = "data/ROS_MDG_microdata/") {
  message("=== Année ", year, " ===")
  
  # res_r.dta
  df_r <- read_dta(paste0(path, year, "/res_r.dta"))
  message("res_r.dta:")
  print(intersect(c("r6", "r7"), names(df_r)))
  
  # res_mo.dta
  mo_file <- paste0(path, year, "/res_mo.dta")
  if (file.exists(mo_file)) {
    df_mo <- read_dta(mo_file)
    message("res_mo.dta:")
    print(names(df_mo))
  } else {
    message("res_mo.dta absent")
  }
  
  # res_ita.dta
  ita_file <- paste0(path, year, "/res_ita.dta")
  if (file.exists(ita_file)) {
    df_ita <- read_dta(ita_file)
    message("res_ita.dta:")
    print(names(df_ita))
  } else {
    message("res_ita.dta absent")
  }
}

inspect_inputs_couts(1995)
inspect_inputs_couts(1996)
inspect_inputs_couts(1997)
inspect_inputs_couts(1998)
inspect_inputs_couts(1990)
inspect_inputs_couts(2001)
inspect_inputs_couts(2002)
inspect_inputs_couts(2003)
inspect_inputs_couts(2004)
inspect_inputs_couts(2005)
inspect_inputs_couts(2006)
inspect_inputs_couts(2007)
inspect_inputs_couts(2008)
inspect_inputs_couts(2009)
inspect_inputs_couts(2010)
