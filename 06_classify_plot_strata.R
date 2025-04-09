# -*- coding: utf-8 -*-
# ---------------------------------------------------------------------------
# "Create Key for Classifying BLM AIM NPR-A Plots"
# Author: Amanda Droghini, Lindsey Flagstad
# Last Updated: 2025-04-08
# Usage: Must be executed in R version 4.4.3+.
# Description: "Create Key for Classifying BLM AIM NPR-A Plots" creates a dichotomous key using various indicators and thresholds and applies it to NPR-A plots.
# ---------------------------------------------------------------------------

# Load packages ----
library(dplyr)
library(fs)
library(readr)
library(readxl)
library(RPostgres)
library(stringr)
library(tidyr)

# Define directories ----

# Set root directory
drive = 'C:'
root_folder = 'ACCS_Work'

# Define input folders
data_folder = path(drive, root_folder, 'Projects/BLM_AIM_NPRA_Benchmarks')
akveg_repository = path(drive, root_folder, 'Repositories/akveg-database')
query_folder = path(drive, root_folder, 'Repositories/aim-npra-benchmarks/queries')
credentials_folder = path(drive, root_folder, 'Servers_Websites/Credentials/akveg_public_read')

# Define files ----

# Define input files
abiotic_file = path(query_folder, 'npra_06_abiotic_query.sql')
veg_cover_file = path(query_folder, 'npra_05_vegetation_query.sql')

indicators_input = path(data_folder, 'Data/Data_Output/summary/AIM_NPRA_Indicator_Summary.csv')

# Define output files
autokey_output = path(data_folder, 'Autokey', 'Draft_Classification_20250408.csv')

# Read in local data ----
indicators_original = read_csv(indicators_input)

# Query AKVEG database ----
# Import database connection function
connection_script = path(akveg_repository, 'package_DataProcessing', 'connect_database_postgresql.R')
source(connection_script)

# Create a connection to the AKVEG PostgreSQL database
authentication = path(credentials_folder, 'authentication_akveg_public_read.csv')
database_connection = connect_database_postgresql(authentication)

# Read abiotic top cover data from AKVEG Database
query_abiotic = read_file(abiotic_file)
query_veg_cover = read_file(veg_cover_file)

abiotic_data = as_tibble(dbGetQuery(database_connection, query_abiotic))
veg_cover_data = as_tibble(dbGetQuery(database_connection, query_veg_cover))

# Calculate additional indicators ----
column_order = colnames(indicators_original)

# Calculate biotic top cover
biotic_top_cover = abiotic_data %>% 
  group_by(site_visit_code) %>% 
  summarise(abiotic_top_cover = sum(abiotic_top_cover_percent)) %>% 
  mutate(biotic_top_cover_percent = 100 - abiotic_top_cover) %>% 
  select(-abiotic_top_cover)

indicators = indicators_original %>% 
  left_join(biotic_top_cover, 'site_visit_code')

# Verify that there are no missing values + values are between 0 and 100
summary(indicators$biotic_top_cover_percent)
indicators %>% filter(is.na(biotic_top_cover_percent)) %>% nrow()

# Calculate Dryas integrifolia cover
indicators = veg_cover_data %>% 
  filter(grepl('dryint', code_accepted) & dead_status=='FALSE') %>% 
  select(site_visit_code, cover_percent) %>% 
  rename(dryint_cover_percent = cover_percent) %>% 
  right_join(indicators, by="site_visit_code") %>%
  mutate(dryint_cover_percent = replace_na(dryint_cover_percent, 0)) %>% 
  select(all_of(column_order), dryint_cover_percent, biotic_top_cover_percent)

# Verify that there are no missing values + values are between 0 and 100
summary(indicators$dryint_cover_percent)
indicators %>% filter(is.na(dryint_cover_percent)) %>% nrow()

# Correct manual stratum classification ----
indicators = indicators %>% 
  mutate(stratum_name = case_when(site_code == 'AB-5B' ~ 'Alpine Dwarf Shrub Tundra',
                                  .default = stratum_name),
         stratum_code = case_when(site_code == 'AB-5B' ~ 'ADST',
                                  .default = stratum_code))

# Create additional indicators ----
indicators = indicators %>% 
  mutate(ripsal_biotic_ratio = ripsal_cover_percent / biotic_top_cover_percent,
         artbor_biotic_ratio = artbor_cover_percent / biotic_top_cover_percent)
  
# Classification ----
autokey = indicators %>% 
  mutate(auto_class = case_when(bare_ground_cover_percent > 20 & umbili_cover_percent > 10 ~ 'Arctic Barren',
                                haloph_cover_percent > 2 ~ 'Tide Marsh Coastal Wetland',
                                bare_ground_cover_percent > 25 & leymus_cover_percent > 10 ~ 'Barrier Island, Spits, Beaches and Dunes',
                                bare_ground_cover_percent > 60 & eursib_cover_percent == 0 & (depth_active_layer_cm > 80 | is.na(depth_active_layer_cm)) & (ripsal_biotic_ratio > 0.1 | artbor_biotic_ratio > 0.1 | poafam_cover_percent > 4) ~ 'Inland Dune',
                                ripsal_cover_percent > 5 | eursib_cover_percent > 2 | dryint_cover_percent > 25 | equarv_cover_percent > 5 | arcrub_cover_percent > 5 ~ 'Arctic Floodplain Shrubland',
                                dwashr_cover_percent > 20 & tussock_cover_percent < 5 & wetsed_cover_percent == 0 & aqumos_cover_percent == 0 ~ 'Alpine Dwarf Shrub Tundra',
                                (salpul_cover_percent + betnan_cover_percent >= 40) & tussock_cover_percent < 15 ~ 'Foothills Low Shrub Tundra',
                                tussock_cover_percent < 3 & wetsed_cover_percent > 40 & caraqu_cover_percent > 15 & dryas_cover_percent == 0 & lichen_cover_percent <= 2 & (organic_depth_cm > 15 | is.na(organic_depth_cm)) & (sphagn_cover_percent + salfus_cover_percent + carcho_cover_percent > 10) ~ 'Foothills Wetlands',
                                soil_pH > 5.6 & wetsed_cover_percent > 10 & tussock_cover_percent < 10 & aqumos_cover_percent > 5 & sphagn_cover_percent < 6 & (organic_depth_cm >= 15 | is.na(organic_depth_cm)) & (surface_water_cover_percent > 1 | !is.na(depth_groundwater_cm)) ~ 'Arctic Floodplain Poorly Drained',
                                (surface_water_cover_percent > 15 | wetsed_cover_percent > 20) & ((caraqu_cover_percent + eriang_cover_percent > 10) | carbig_cover_percent > 1 ) ~ 'Sand Sheet Wetland',
                                surface_water_cover_percent > 10 & (caraqu_cover_percent + eriang_cover_percent + carcho_cover_percent > 1) ~ 'Coastal Plain Wetland',
                                tussock_wetsed_ratio > 0.6 & erifam_cover_percent > 30 ~ 'Foothills Tussock Tundra',
                                tussock_wetsed_ratio > 0.6 & (cladon_cover_percent + flavoc_cover_percent + thamno_cover_percent > 10) ~ 'Sand Sheet Moist Tundra', 
                                erifam_cover_percent > 10 & (caraqu_cover_percent + eriang_cover_percent >10) ~ 'Coastal Plain Moist Tundra',
                                .default = 'unassigned')) 

# Format export table ----
autokey_final = autokey %>% 
  select(site_code, 
         stratum_name,
         auto_class,
         bare_ground_cover_percent,
         surface_water_cover_percent,
         biotic_top_cover_percent,
         depth_active_layer_cm,
         depth_groundwater_cm,
         soil_pH,
         organic_depth_cm,
         arcrub_cover_percent,
         artbor_cover_percent,
         aqumos_cover_percent,
         betnan_cover_percent,
         caraqu_cover_percent,
         carbig_cover_percent,
         carcho_cover_percent,
         cladon_cover_percent,
         dryas_cover_percent,
         dryint_cover_percent,
         dwashr_cover_percent,
         equarv_cover_percent,
         eriang_cover_percent,
         erifam_cover_percent,
         eursib_cover_percent,
         flavoc_cover_percent,
         haloph_cover_percent,
         leymus_cover_percent,
         poafam_cover_percent,
         ripsal_cover_percent,
         salfus_cover_percent,
         salpul_cover_percent,
         sphagn_cover_percent,
         thamno_cover_percent,
         umbili_cover_percent, 
         wetsed_cover_percent,
         artbor_biotic_ratio,
         moss_lichen_ratio,
         ripsal_biotic_ratio,
         tussock_wetsed_ratio
         ) %>% 
  arrange(auto_class, stratum_name) %>% 
  mutate(across(where(is.numeric), ~round(., digits=3))) # Round all numeric columns to 3 digits, thanks to @upuil for the solution: https://stackoverflow.com/questions/9063889/how-to-round-a-data-frame-in-r-that-contains-some-character-variables

# QA/QC ----
temp = autokey_final %>% 
  filter(stratum_name == 'Coastal Plain Moist Tundra' | auto_class == 'Coastal Plain Moist Tundra') %>% 
  select(site_code, stratum_name, auto_class, 
         surface_water_cover_percent,
         erifam_cover_percent,
         caraqu_cover_percent,
         eriang_cover_percent) %>% 
  arrange(stratum_name)

# Export as CSV ----
write_csv(autokey_final, file=autokey_output)

# Clear workspace ----
rm(list=ls())
