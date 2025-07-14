household_geolocated %>%
  filter(j0 == "3") %>%
  filter(str_starts(j5, "031")) %>%
  filter(str_ends(j5, "001")) %>%
  select(year, j5, j4)

household_geolocated %>%
  filter(j0 == "3") %>%
  filter(str_starts(j5, "032")) %>%
  filter(str_ends(j5, "001")) %>%
  select(year, j5, j4)

household_geolocated %>%
  filter(j0 == "3") %>%
  filter(str_starts(j5, "033")) %>%
  filter(str_ends(j5, "004")) %>%
  select(year, j5, j4)



test4 <- household_geolocated %>%
  filter(j0 == "1") %>%
  filter(str_starts(j5, "012")) %>%
  filter(str_ends(j5, "001")) %>%
  select(j5, j4)


test2 <- household_geolocated %>%
  mutate(j5_length = str_length(j5)) %>%
  group_by(year, j5_length) %>%
  summarise(n = n(), .groups = "drop") %>%
  arrange(year, j5_length)

test3 <- household_geolocated %>%
  filter(str_length(j5) == 6)



test5 <- household_geolocated %>%
  mutate(or_id = str_sub(j5, 1, 2)) %>%
  group_by(year, site_id) %>%
  summarise(n = n())

# Check 3rd and 4th digit
test6 <- household_geolocated %>%
  mutate(or_id = str_sub(j5, 1, 2),
         site_id = str_sub(j5, 3, 4)) %>%
  group_by(year, or_id, site_id) %>%
  summarise(n = n()) %>%
  filter(or_id == "04") %>%
  pivot_wider(names_from = site_id, values_from = n)


