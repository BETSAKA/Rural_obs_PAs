mo95 <- read_dta("data/ROS_MDG_microdata/1995/res_mo3.dta")
attr(mo95$moc, "labels")

mo1_96 <- read_dta("data/ROS_MDG_microdata/1996/res_mo1.dta")
mo3_96 <- read_dta("data/ROS_MDG_microdata/1996/res_mo3.dta")

mo1_97 <- read_dta("data/ROS_MDG_microdata/1997/res_mo1.dta")
mo3_97 <- read_dta("data/ROS_MDG_microdata/1997/res_mo3.dta")


mo1_98 <- read_dta("data/ROS_MDG_microdata/1998/res_mo1.dta")
mo3_98 <- read_dta("data/ROS_MDG_microdata/1998/res_mo3.dta")

mo1_01 <- read_dta("data/ROS_MDG_microdata/2001/res_mo1.dta")
mo3_01 <- read_dta("data/ROS_MDG_microdata/2001/res_mo3.dta")

mo1_09 <- read_dta("data/ROS_MDG_microdata/2009/res_mo1.dta")
mo3_09 <- read_dta("data/ROS_MDG_microdata/2009/res_mo3.dta")


r95 <- read_dta("data/ROS_MDG_microdata/1995/res_r.dta")
r_tot95 <- read_dta("data/ROS_MDG_microdata/1995/res_r_tot.dta")
r60_95 <- read_dta("data/ROS_MDG_microdata/1995/res_r60.dta")
c95 <- read_dta("data/ROS_MDG_microdata/1995/res_c.dta")

attr(c95$c5, "labels")


mo1_96 <- read_dta("data/ROS_MDG_microdata/1996/res_mo1.dta")
mo1_97 <- read_dta("data/ROS_MDG_microdata/1997/res_mo1.dta")
mo1_98 <- read_dta("data/ROS_MDG_microdata/1998/res_mo1.dta")


m97 <- read_dta("data/ROS_MDG_microdata/1997/res_m_a.dta")
as06 <- read_dta("data/ROS_MDG_microdata/2006/res_as.dta")
as05 <- read_dta("data/ROS_MDG_microdata/2005/res_as.dta")
m05  <- read_dta("data/ROS_MDG_microdata/2005/res_m_a.dta")

colnames(mo1_98)
colnames(mo1_97)
colnames(mo1_96)
# Correspondance ménage-observatoire

path <- "data/ROS_MDG_microdata/"
year <- 1995
household_to_obs <- read_dta(paste0(path, year, "/res_deb.dta")) %>%
  select(j5, obs = j0) 

test_dub <- household_to_obs %>% count(j5) %>% filter(n > 1)


household_to_obs2 <- read_dta(paste0(path, year, "/res_deb.dta")) %>%
  select(j5, obs = j0) %>%
  distinct()

##############

# Stats descriptives sur les charges riz 2011–2015
df_riz <- map_dfr(2015:1995, function(y) {
  df <- process_rev_riz(path = "data/ROS_MDG_microdata/", year = y)
})
ggplot(df_riz, aes(x = factor(year), y = rev_riz)) +
  geom_boxplot(outlier.alpha = 0.2) +
  labs(x = "Année", y = "Revenu riz (MGA)", title = "Distribution du revenu riz par année") +
  theme_minimal() +
  theme(axis.text.x = element_text(angle = 45, hjust = 1))


ggplot(df_riz, aes(x = factor(year), y = rev_riz)) +
  geom_boxplot(outlier.shape = NA) +  # Hides the outlier points
  labs(x = "Année", y = "Revenu riz (MGA)", title = "Distribution du revenu riz par année") +
  theme_minimal() +
  theme(axis.text.x = element_text(angle = 45, hjust = 1))

library(dplyr)
library(ggplot2)

# Step 1: Compute IQR-based thresholds per year
df_truncated <- df_riz %>%
  group_by(year) %>%
  mutate(
    Q1 = quantile(rev_riz, 0.25, na.rm = TRUE),
    Q3 = quantile(rev_riz, 0.75, na.rm = TRUE),
    IQR = Q3 - Q1,
    lower = Q1 - 1.5 * IQR,
    upper = Q3 + 1.5 * IQR
  ) %>%
  ungroup() %>%
  filter(rev_riz >= lower & rev_riz <= upper)

# Step 2: Plot the truncated data
ggplot(df_truncated, aes(x = factor(year), y = rev_riz)) +
  geom_boxplot() +
  labs(x = "Année", y = "Revenu riz (MGA)", title = "Distribution du revenu riz par année (hors valeurs extrêmes)") +
  theme_minimal() +
  theme(axis.text.x = element_text(angle = 45, hjust = 1))

test_summary <- test %>%
  summarise(
    year = y,
    n = n(),
    moyenne = mean(rev_riz, na.rm = TRUE),
    mediane = median(rev_riz, na.rm = TRUE),
    min = min(rev_riz, na.rm = TRUE),
    max = max(rev_riz, na.rm = TRUE))
    print(test, n = 21)

    
    df_revppal <- map_dfr(2015:1995, function(y) {
      print(y)
      df <- process_revppal(path = "data/ROS_MDG_microdata/", year = y)
    })
    
 
    df_revppal%>%
      filter(revppal > 0 ) %>%
      ggplot(aes(x = factor(year), y = revppal)) +
      geom_boxplot(outlier.alpha = 0.2) +
      labs(x = "Année", y = "Revenu riz (MGA)", title = "Distribution du revenu riz par année") +
      theme_minimal() +
      theme(axis.text.x = element_text(angle = 45, hjust = 1))
    
    
    df_revsec <- map_dfr(2015:1995, function(y) {
      print(y)
      df <- process_revsec(path = "data/ROS_MDG_microdata/", year = y)
    })
    
    as03 <- read_dta("data/ROS_MDG_microdata/2003/res_as.dta")
    
    test <- as03 %>%
      mutate(bla  = as.numeric(as3) * as.numeric(as4))
    