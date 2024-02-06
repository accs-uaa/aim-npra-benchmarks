# -*- coding: utf-8 -*-
# ---------------------------------------------------------------------------
# Summarize AIM indicators
# Author: Timm Nawrocki, Alaska Center for Conservation Science
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
herbaceous_file = path(data_folder,"15_herbaceousstructure_aimvarious2021.csv")

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

# 1. depth_moss_duff_cm and depth_15_percent_coarse_fragments_cm
# No filtering or summarizaton needed, simply append to existing indicators table
# Do you want to convert -999 values to NA?
indicators = environment_data %>% 
  group_by(site_visit_code) %>% 
  mutate(depth_moss_duff_cm = gsub(pattern=-999,replacement=NA,x=depth_moss_duff_cm),
         depth_15_percent_coarse_fragments_cm = gsub(pattern=-999,
                                                     replacement=NA,
                                                     x=depth_15_percent_coarse_fragments_cm)) %>% 
  select(site_visit_code, depth_moss_duff_cm, depth_15_percent_coarse_fragments_cm) %>%
  left_join(indicators, by = "site_visit_code")%>% 
  arrange(site_visit_code)

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

# 3. surface_water_depth_cm 
# (drop -999 and positive (+) values; make negative values positive)
# Do you want to keep zero values?
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

# Calculate surface_water_cover_percent (ground_element == water) and biotic_cover_percent (ground_element == biotic)
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
# TWN: There is one site "ADST-72" that has PF04 as name_original, becomes 'herbaceous' as name_adjudicated, is that coded appropriately?
indicators = herbaceous_data %>% 
  group_by(site_visit_code) %>% 
  filter(name_original == "herbaceous" & height_type == "point-intercept mean") %>% # Missing CPBWM-29
  rename(herbaceous_mean_height_cm = height_cm) %>% 
  select(site_visit_code,herbaceous_mean_height_cm) %>% 
  right_join(indicators, by = "site_visit_code") %>% 
  arrange(site_visit_code)

# QA/QC
summary(indicators$herbaceous_mean_height_cm) # One site missing (CPBWM-29)

# Calculate shrub height indicator ----
indicators = shrub_data %>% 
  group_by(site_visit_code) %>% 
  filter(name_accepted == "shrub" & height_type == "point-intercept mean") %>% 
  rename(shrub_mean_height_cm = height_cm) %>% 
  select(site_visit_code,shrub_mean_height_cm) %>% 
  right_join(indicators, by = "site_visit_code") %>% 
  arrange(site_visit_code)

# QA/QC
summary(indicators$shrub_mean_height_cm) # Missing data from 17 sites

# 