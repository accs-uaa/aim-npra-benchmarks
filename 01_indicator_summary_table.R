# -*- coding: utf-8 -*-
# ---------------------------------------------------------------------------
# Summarize AIM indicators
# Author: Amanda Droghini, Timm Nawrocki, Alaska Center for Conservation Science
# Last Updated: 2024-02-06
# Usage: Script should be executed in R 4.3.2+.
# Description: "Summarize AIM indicators" creates an indicator summary table from the AKVEG Database.
# ---------------------------------------------------------------------------

# Import required libraries
library(dplyr)
library(fs)
library(readr)
library(readxl)
library(RPostgres)
library(stringr)
library(tibble)
library(tidyr)

# Set root directory
drive = 'D:'
root_folder = 'ACCS_Work'

# Define input folders
data_folder = path(drive, root_folder, 'Projects/VegetationEcology/BLM_AIM_NPRA_Benchmarks')
akveg_repository = 'C:/ACCS_Work/GitHub/akveg-database'
benchmark_repository= 'C:/ACCS_Work/GitHub/aim-npra-benchmarks'
query_folder = path(benchmark_repository, 'queries')
credentials_folder = path("C:/ACCS_Work/Servers_Websites/Credentials/accs-postgresql")

# Define input files
site_visit_file = path(query_folder, 'npra_03_site_visit_query.sql')
vegetation_file = path(query_folder, 'npra_05_vegetation_query.sql')
abiotic_file = path(query_folder, 'npra_06_abiotic_query.sql')
ground_file = path(query_folder, 'npra_08_ground_query.sql')
shrub_file = path(query_folder, 'npra_11_shrub_query.sql')
environment_file = path(query_folder, 'npra_12_environment_query.sql')
soil_metrics_file = path(query_folder, 'npra_13_soil_metrics_query.sql')
soil_horizons_file = path(query_folder, 'npra_14_soil_horizons_query.sql')
herbaceous_file = path(data_folder, '15_herbaceousstructure_aimvarious2021.csv')

# Define output files
output_file = path(data_folder, 'AIM_NPRA_Indicator_Summary.csv')

# Import database connection function
connection_script = path(akveg_repository, 'package_DataProcessing', 'connect_database_postgresql.R')
source(connection_script)

# Create a connection to the AKVEG PostgreSQL database
authentication = path(credentials_folder, 'authentication_akveg.csv')
database_connection = connect_database_postgresql(authentication)

# Read site visit data from AKVEG Database
site_visit_query = read_file(site_visit_file)
site_visit_data = as_tibble(dbGetQuery(database_connection, site_visit_query))

# Read vegetation cover data from AKVEG Database
vegetation_query = read_file(vegetation_file)
vegetation_data = as_tibble(dbGetQuery(database_connection, vegetation_query))

# Read abiotic top cover data from AKVEG Database
abiotic_query = read_file(abiotic_file)
abiotic_data = as_tibble(dbGetQuery(database_connection, abiotic_query))

# Read ground cover data from AKVEG Database
ground_query = read_file(ground_file)
ground_data = as_tibble(dbGetQuery(database_connection, ground_query))

# Read shrub structure data from AKVEG Database
shrub_query = read_file(shrub_file)
shrub_data = as_tibble(dbGetQuery(database_connection, shrub_query))

# Read environment data from AKVEG Database
environment_query = read_file(environment_file)
environment_data = as_tibble(dbGetQuery(database_connection, environment_query))

# Read soil metrics data from AKVEG Database
soil_metrics_query = read_file(soil_metrics_file)
soil_metrics_data = as_tibble(dbGetQuery(database_connection, soil_metrics_query))

# Read soil horizons data from AKVEG Database
soil_horizons_query = read_file(soil_horizons_file)
soil_horizons_data = as_tibble(dbGetQuery(database_connection, soil_horizons_query)) # 4 sites missing data

# Read herbaceous heights data from local folder
herbaceous_data = read_csv(herbaceous_file)

# Calculate abiotic top cover indicator ----

# Calculate bare ground cover percent
# Where bare ground cover % = soil + rock fragments
indicators = abiotic_data %>% 
  group_by(site_visit_code) %>% 
  filter(abiotic_element == "soil" | abiotic_element == "rock fragments") %>% 
  summarize(bare_ground_cover_percent = sum(abiotic_top_cover_percent)) %>% 
  mutate(bare_ground_cover_percent = round(x=bare_ground_cover_percent,digits=2))

# Calculate environment indicators ----

# Summary of depth_15_percent_coarse_fragments_cm not included since most sites (248/261) have a value of -999 for that variable

# 1. depth_moss_duff_cm 
# No filtering or summarizaton needed, simply append to existing indicators table
# Replace -999 (null) values with NA
indicators = environment_data %>% 
  group_by(site_visit_code) %>% 
  mutate(depth_moss_duff_cm = na_if(depth_moss_duff_cm, -999)) %>%
  select(site_visit_code, depth_moss_duff_cm) %>%
  right_join(indicators, by = "site_visit_code")%>% 
  arrange(site_visit_code)

summary(indicators$depth_moss_duff_cm)

# 2. depth_active_layer_cm
# restrictive_type == permafrost & sites with -999 for depth or restrictive_type != permafrost should be dropped

# Select only permafrost sites
# Drop any permafrost sites that have a NULL value for depth (listed as -999). In this dataset, all values with a depth_restrictive_layer == -999 have NA as a restrictive type.
indicators = environment_data %>% 
  group_by(site_visit_code) %>% 
  filter(restrictive_type == "permafrost") %>% 
  filter(depth_restrictive_layer_cm != -999) %>% 
  rename(depth_active_layer_cm = depth_restrictive_layer_cm) %>% 
  select(site_visit_code,depth_active_layer_cm) %>% 
  right_join(indicators,by="site_visit_code") %>% 
  arrange(site_visit_code)

summary(indicators$depth_active_layer_cm)

# 3. surface_water_depth_cm 
# Ddrop -999 and positive (+) values; make negative values positive
indicators = environment_data %>% 
  group_by(site_visit_code) %>% 
  filter(depth_water_cm != -999 & depth_water_cm <= 0) %>% 
  mutate(surface_water_depth_cm = depth_water_cm * -1) %>% 
  select(site_visit_code, surface_water_depth_cm) %>% 
  right_join(indicators,by="site_visit_code") %>% 
  arrange(site_visit_code)

# QA/QC: All surface water values are positive
summary(indicators$surface_water_depth_cm)

# Calculate ground cover indicators ----

# Calculate surface_water_cover_percent (ground_element == water)
# Calculate biotic_cover_percent (ground_element == biotic)
indicators = ground_data %>% 
  group_by(site_visit_code) %>% 
  filter(ground_element == "water" | ground_element == "biotic") %>% 
  select(site_visit_code,ground_element,ground_cover_percent) %>% 
  pivot_wider(names_from = ground_element, values_from = ground_cover_percent) %>% 
  rename(surface_water_cover_percent = water,
         biotic_cover_percent = biotic) %>%
  right_join(indicators, by = "site_visit_code") %>% 
  arrange(site_visit_code)

# Calculate herbaceous height indicator ----
indicators = herbaceous_data %>% 
  group_by(site_visit_code) %>%
  filter(name_adjudicated == "herbaceous") %>% # Missing CPBWM-29
  pivot_wider(id_cols = site_visit_code, 
              names_from = height_type, 
              values_from = height_cm) %>% 
  rename(herbaceous_mean_height_cm = "point-intercept mean",
         herbaceous_max_height_cm = "point-intercept 98th percentile") %>% 
  select(site_visit_code,herbaceous_mean_height_cm, herbaceous_max_height_cm) %>% 
  right_join(indicators, by = "site_visit_code") %>% 
  arrange(site_visit_code)

# QA/QC
summary(indicators$herbaceous_mean_height_cm) # One site missing (CPBWM-29)
summary(indicators$herbaceous_max_height_cm) # All values greater than mean heights

# Calculate shrub height indicator ----
indicators = shrub_data %>% 
  group_by(site_visit_code) %>% 
  filter(name_accepted == "shrub") %>% 
  pivot_wider(id_cols = site_visit_code,
              names_from = height_type, 
              values_from = height_cm) %>% 
  rename(shrub_mean_height_cm = "point-intercept mean",
         shrub_max_height_cm = "point-intercept 98th percentile") %>% 
  select(site_visit_code,shrub_mean_height_cm, shrub_max_height_cm) %>% 
  right_join(indicators, by = "site_visit_code") %>%
  mutate(shrub_mean_height_cm = case_when(site_visit_code != "CPBWM-29_20130731" 
                                          & is.na(shrub_mean_height_cm) ~ 0,
                                          .default = shrub_mean_height_cm),
         shrub_max_height_cm = case_when(site_visit_code != "CPBWM-29_20130731" 
                                         & is.na(shrub_max_height_cm) ~ 0,
                                         .default = shrub_max_height_cm)) %>% 
  arrange(site_visit_code)

# QA/QC
summary(indicators$shrub_mean_height_cm) # Should be only one NA from CPBWM-29; all others were converted to zero
summary(indicators$shrub_max_height_cm) # All values greater than mean heights

# Calculate shrub/herb ratio height indicator ----
indicators = indicators %>% 
  group_by(site_visit_code) %>% 
  mutate(shrub_herbaceous_height_ratio = case_when(!is.na(shrub_mean_height_cm) & !is.na(herbaceous_mean_height_cm) ~
                                                     shrub_mean_height_cm / 
                                                     (shrub_mean_height_cm + herbaceous_mean_height_cm + 0.001),
                                                   is.na(shrub_mean_height_cm) | is.na(herbaceous_mean_height_cm) ~ NA)) %>% 
  mutate(shrub_herbaceous_height_ratio = round(shrub_herbaceous_height_ratio, digits = 2))

# QA/QC
summary(indicators$shrub_herbaceous_height_ratio) # 1 missing site; ratio bounded by 0 and 1

# Calculate soil metrics indicator ----

# Order of priority for value to retain: if water measurement exists, use it; then if 10 cm measurement exists, use it; then if 30 cm measurement exists, use it.

min_soil_depth = soil_metrics_data %>% 
  filter(ph != -999) %>%
  group_by(site_visit_code) %>% 
  summarize(min_depth = min(measure_depth_cm))

indicators = soil_metrics_data %>%
  filter(ph != -999) %>%
  left_join(min_soil_depth, by="site_visit_code") %>% 
  filter(measure_depth_cm == min_depth) %>% 
  rename(soil_pH = ph) %>% 
  select(site_visit_code,soil_pH) %>% 
  right_join(indicators, by = "site_visit_code") %>% 
  arrange(site_visit_code)

summary(indicators$soil_pH) # 6 sites with NAs

soil_metrics_data %>% filter(ph == -999) %>% nrow() # 8 entries with null values, but 2 sites had 2 entries each (6 unique sites)

# Calculate soil horizons indicators ----

# Calculate organic depth
indicators = soil_horizons_data %>% 
  group_by(site_visit_code) %>% 
  filter(horizon_primary_code=="O") %>% 
  mutate(thickness_cm = case_when(thickness_cm == -999 ~ depth_lower_cm - depth_upper_cm,
                                  .default = thickness_cm)) %>% 
  summarise(organic_depth_cm = sum(thickness_cm)) %>% 
  right_join(indicators, by = "site_visit_code") %>% 
  arrange(site_visit_code)

summary(indicators$organic_depth_cm)

# Calculate organic:mineral ratio
# Restrict to the first 30 cm of soil
indicators = soil_horizons_data %>%
  mutate(horizon_type = case_when(horizon_primary_code == 'O' ~ 'organic',
                                  horizon_primary_code != 'O' ~ 'mineral')) %>%
  group_by(site_visit_code, horizon_type) %>%
  filter(depth_upper_cm < 30) %>%
  mutate(depth_lower_cm = case_when(depth_lower_cm > 30 ~ 30,
                                    TRUE ~ depth_lower_cm)) %>%
  filter(depth_lower_cm != -999) %>%
  mutate(thickness_cm = depth_lower_cm - depth_upper_cm) %>%
  select(site_visit_code, horizon_primary_code, thickness_cm) %>%
  summarize(thickness_sum_cm = sum(thickness_cm)) %>%
  pivot_wider(names_from = horizon_type, values_from = thickness_sum_cm) %>%
  mutate(organic_mineral_ratio_30_cm = case_when(is.na(organic) ~ 0,
                                                 is.na(mineral) ~ 1,
                                                 !is.na(organic) & !is.na (mineral) ~
                                                   organic/(organic + mineral + 0.001),
                                                 TRUE ~ -999)) %>%
  mutate(organic_mineral_ratio_30_cm = round(organic_mineral_ratio_30_cm, 2)) %>%
  select(-c(organic, mineral)) %>% 
  right_join(indicators, by = "site_visit_code") %>% 
  arrange(site_visit_code)

summary(indicators$organic_mineral_ratio_30_cm) # 4 sites with missing values; ratio bounded by 0 and 1

# Re-arrange columns
# So that the shrub/herbaceous heights columns are all together
indicators = indicators %>% 
  select(site_visit_code, organic_mineral_ratio_30_cm, organic_depth_cm,
         soil_pH,shrub_herbaceous_height_ratio,everything())

# Export to CSV
write_csv(indicators,output_file)

# Clear workspace
rm(list=ls())