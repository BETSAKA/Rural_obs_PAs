library(tidyverse)
library(haven)

deb_11 <- read_dta("data/ROS_MDG_microdata/2011/res_deb.dta") %>%
  filter(j0 == 21) %>%
  mutate(site_id = substr(j5, 1, 3),
         ham_id = substr(j5, 1, 4))
deb_12 <- read_dta("data/ROS_MDG_microdata/2012/res_deb.dta") %>%
  filter(j0 == 21) %>%
  mutate(site_id = substr(j5, 1, 3),
         ham_id = substr(j5, 1, 4))
deb_13 <- read_dta("data/ROS_MDG_microdata/2013/res_deb.dta") %>%
  filter(j0 == 21) %>%
  mutate(site_id = substr(j5, 1, 3),
         ham_id = substr(j5, 1, 4))
deb_14 <- read_dta("data/ROS_MDG_microdata/2014/res_deb.dta")%>%
  filter(j0 == 21) %>%
  mutate(site_id = substr(j5, 1, 3),
         ham_id = substr(j5, 1, 4))

ampa_11 <- deb_11 %>%
  filter(site_id == 212) %>%
  select(year, j5, j4:j41, j09, j20:j13, site_id, ham_id)
ampa_12 <- deb_12 %>%
  filter(site_id == 212)  %>%
  select(year, j5, j4:j41, j09, j20:j13, site_id, ham_id)
ampa_13 <- deb_13 %>%
  filter(site_id == 212)  %>%
  select(year, j5, j4:j41, j09, j20:j13, site_id, ham_id) %>%
  mutate(j12 = as.character(j12))
ampa_14 <- deb_14 %>%
  filter(site_id == 212)  %>%
  select(year, j5, j4:j41, j09, j20:j13, site_id, ham_id) %>%
  mutate(j12 = as.character(j12))

ampa_all <- bind_rows(ampa_11, ampa_12, ampa_13, ampa_14)

n_ham <- ampa_all %>%
  group_by(j4, year) %>%
  summarise(n = n()) %>%
  pivot_wider(names_from = j4, values_from = n)


history_hh <- ampa_all %>%
  select(j5, j4, year) %>%
  pivot_wider(names_from = year, values_from = j4)

hist_mari <- history_hh %>%
  filter(`2013` == "Maritampona")

hist_mari %>%
  group_by(`2012`) %>%
  summarise(n = n())



maritampona_13 <- ampa_all %>%
  filter(year == 2013 & j4 == "Maritampona")
