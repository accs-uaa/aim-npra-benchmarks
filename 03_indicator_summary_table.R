# -*- coding: utf-8 -*-
# ---------------------------------------------------------------------------
# Summarize AIM indicators
# Author: Amanda Droghini, Timm Nawrocki, Alaska Center for Conservation Science
# Last Updated: 2024-02-07
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
akveg_repository = path(drive, root_folder, 'Repositories/akveg-database')
query_folder = path(drive, root_folder, 'Repositories/aim-npra-benchmarks/queries')
credentials_folder = path(drive, root_folder, 'Administrative/Credentials/akveg_private_read')

# Define input files
site_visit_file = path(query_folder, 'npra_03_site_visit_query.sql')
vegetation_file = path(query_folder, 'npra_05_vegetation_query.sql')
abiotic_file = path(query_folder, 'npra_06_abiotic_query.sql')
ground_file = path(query_folder, 'npra_08_ground_query.sql')
shrub_file = path(query_folder, 'npra_11_shrub_query.sql')
environment_file = path(query_folder, 'npra_12_environment_query.sql')
soil_metrics_file = path(query_folder, 'npra_13_soil_metrics_query.sql')
soil_horizons_file = path(query_folder, 'npra_14_soil_horizons_query.sql')
herbaceous_input = path(data_folder, 'Data/Data_Input/herbaceous/15_herbaceousstructure_aimvarious2021.csv')
strata_input = path(data_folder, 'Data/Data_Output/strata/AIM_NPRA_Strata.csv')
functional_input = path(data_folder, 'Data/Data_Output/functional_groups/AIM_NPRA_Functional_Groups.csv')

# Define output files
indicators_output = path(data_folder, 'Data/Data_Output/summary/AIM_NPRA_Indicator_Summary.csv')
longform_output = path(data_folder, 'Data/Data_Output/summary/AIM_NPRA_Indicator_Value.csv')

# Read local data
strata_data = read_csv(strata_input)
functional_data = read_csv(functional_input)
herbaceous_data = read_csv(herbaceous_input)

#### QUERY AKVEG DATABASE
####------------------------------

# Import database connection function
connection_script = path(akveg_repository, 'package_DataProcessing', 'connect_database_postgresql.R')
source(connection_script)

# Create a connection to the AKVEG PostgreSQL database
authentication = path(credentials_folder, 'authentication_akveg_private.csv')
database_connection = connect_database_postgresql(authentication)

# Read site visit data from AKVEG Database
site_visit_query = read_file(site_visit_file)
site_visit_data = as_tibble(dbGetQuery(database_connection, site_visit_query)) %>%
  select(-site_code)

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

#### CALCULATE ENVIRONMENTAL INDICATORS
####------------------------------

# Calculate bare ground cover percent (ground cover % = soil + rock fragments)
indicators = abiotic_data %>% 
  group_by(site_visit_code) %>% 
  filter(abiotic_element == "soil" | abiotic_element == "rock fragments") %>% 
  summarize(bare_ground_cover_percent = sum(abiotic_top_cover_percent)) %>% 
  mutate(bare_ground_cover_percent = round(x=bare_ground_cover_percent,digits=2))

# Calculate depth_moss_duff_cm (Replace -999 values with NA)
indicators = environment_data %>% 
  group_by(site_visit_code) %>% 
  mutate(depth_moss_duff_cm = na_if(depth_moss_duff_cm, -999)) %>%
  select(site_visit_code, depth_moss_duff_cm) %>%
  right_join(indicators, by = "site_visit_code")%>% 
  arrange(site_visit_code)

summary(indicators$depth_moss_duff_cm)

# Calculate depth_active_layer_cm (restrictive_type == permafrost & sites with -999 for depth or restrictive_type != permafrost should be dropped)
indicators = environment_data %>% 
  group_by(site_visit_code) %>% 
  filter(restrictive_type == "permafrost") %>% 
  filter(depth_restrictive_layer_cm != -999) %>% 
  rename(depth_active_layer_cm = depth_restrictive_layer_cm) %>% 
  select(site_visit_code,depth_active_layer_cm) %>% 
  right_join(indicators,by="site_visit_code") %>% 
  arrange(site_visit_code)

summary(indicators$depth_active_layer_cm)

# Calculate surface_water_depth_cm (drop -999 and positive (+) values; make negative values positive)
indicators = environment_data %>% 
  group_by(site_visit_code) %>% 
  filter(depth_water_cm != -999 & depth_water_cm <= 0) %>% 
  mutate(surface_water_depth_cm = depth_water_cm * -1) %>% 
  select(site_visit_code, surface_water_depth_cm) %>% 
  right_join(indicators,by="site_visit_code") %>% 
  arrange(site_visit_code)

# QA/QC: All surface water values are positive
summary(indicators$surface_water_depth_cm)

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

#### CALCULATE HEIGHT INDICATORS
####------------------------------

# Calculate herbaceous height indicator
indicators = herbaceous_data %>% 
  group_by(site_visit_code) %>%
  filter(name_adjudicated == "herbaceous") %>% # Missing CPBWM-29
  pivot_wider(id_cols = site_visit_code, 
              names_from = height_type, 
              values_from = height_cm) %>% 
  rename(herbac_mean_height_cm = "point-intercept mean",
         herbac_max_height_cm = "point-intercept 98th percentile") %>% 
  select(site_visit_code,herbac_mean_height_cm, herbac_max_height_cm) %>% 
  right_join(indicators, by = "site_visit_code") %>% 
  arrange(site_visit_code)

# QA/QC
summary(indicators$herbac_mean_height_cm) # One site missing (CPBWM-29)
summary(indicators$herbac_max_height_cm) # All values greater than mean heights

# Calculate shrub height indicator
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

# Calculate shrub/herb ratio height indicator
indicators = indicators %>% 
  group_by(site_visit_code) %>% 
  mutate(shrub_herbac_height_ratio = case_when(!is.na(shrub_mean_height_cm) & !is.na(herbac_mean_height_cm) ~
                                                 shrub_mean_height_cm / 
                                                 (shrub_mean_height_cm + herbac_mean_height_cm + 0.001),
                                               is.na(shrub_mean_height_cm) & !is.na(herbac_mean_height_cm) ~ 0,
                                               !is.na(shrub_mean_height_cm) & is.na(herbac_mean_height_cm) ~ 1,
                                               is.na(shrub_mean_height_cm) & is.na(herbac_mean_height_cm) ~ NA)) %>% 
  mutate(shrub_herbac_height_ratio = round(shrub_herbac_height_ratio, digits = 2))

# QA/QC
summary(indicators$shrub_herbac_height_ratio) # 1 missing site; ratio bounded by 0 and 1

#### CALCULATE SOIL INDICATORS
####------------------------------

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
         soil_pH,shrub_herbac_height_ratio,everything())

#### CALCULATE VEGETATION INDICATORS
####------------------------------

# Calculate wetland sedge indicator
indicators = vegetation_data %>%
  left_join(functional_data, by = c('name_accepted' = 'taxon_accepted')) %>%
  filter(wetland_sedge == 'wetland sedge' & dead_status == 'FALSE') %>%
  group_by(site_visit_code) %>%
  summarize(wetsed_cover_percent = sum(cover_percent)) %>%
  right_join(indicators, by = 'site_visit_code') %>%
  mutate(wetsed_cover_percent = case_when(is.na(wetsed_cover_percent) ~ 0,
                                          TRUE ~ wetsed_cover_percent))

# Calculate facultative wet indicator
indicators = vegetation_data %>%
  left_join(functional_data, by = c('name_accepted' = 'taxon_accepted')) %>%
  filter(wetland_status == 'FACW' & dead_status == 'FALSE') %>%
  group_by(site_visit_code) %>%
  summarize(facw_cover_percent = sum(cover_percent)) %>%
  right_join(indicators, by = 'site_visit_code') %>%
  mutate(facw_cover_percent = case_when(is.na(facw_cover_percent) ~ 0,
                                        TRUE ~ facw_cover_percent))

# Calculate obligate wet indicator
indicators = vegetation_data %>%
  left_join(functional_data, by = c('name_accepted' = 'taxon_accepted')) %>%
  filter(wetland_status == 'OBL' & dead_status == 'FALSE') %>%
  group_by(site_visit_code) %>%
  summarize(obl_cover_percent = sum(cover_percent)) %>%
  right_join(indicators, by = 'site_visit_code') %>%
  mutate(obl_cover_percent = case_when(is.na(obl_cover_percent) ~ 0,
                                       TRUE ~ obl_cover_percent))

# Calculate aquatic moss cover
indicators = vegetation_data %>%
  left_join(functional_data, by = c('name_accepted' = 'taxon_accepted')) %>%
  filter(nv_functional_gr == 'aquatic moss' & dead_status == 'FALSE') %>%
  group_by(site_visit_code) %>%
  summarize(aqumos_cover_percent = sum(cover_percent)) %>%
  right_join(indicators, by = 'site_visit_code') %>%
  mutate(aqumos_cover_percent = case_when(is.na(aqumos_cover_percent) ~ 0,
                                          TRUE ~ aqumos_cover_percent))

# Calculate Sphagnum cover
indicators = vegetation_data %>%
  left_join(functional_data, by = c('name_accepted' = 'taxon_accepted')) %>%
  filter(taxon_genus == 'Sphagnum' & dead_status == 'FALSE') %>%
  group_by(site_visit_code) %>%
  summarize(sphagn_cover_percent = sum(cover_percent)) %>%
  right_join(indicators, by = 'site_visit_code') %>%
  mutate(sphagn_cover_percent = case_when(is.na(sphagn_cover_percent) ~ 0,
                                          TRUE ~ sphagn_cover_percent))

# Calculate mesic moss cover
indicators = vegetation_data %>%
  left_join(functional_data, by = c('name_accepted' = 'taxon_accepted')) %>%
  filter(mesic_moss == 'mesic moss' & dead_status == 'FALSE') %>%
  group_by(site_visit_code) %>%
  summarize(mesmos_cover_percent = sum(cover_percent)) %>%
  right_join(indicators, by = 'site_visit_code') %>%
  mutate(mesmos_cover_percent = case_when(is.na(mesmos_cover_percent) ~ 0,
                                          TRUE ~ mesmos_cover_percent))

# Calculate n-fixing feathermoss cover
indicators = vegetation_data %>%
  left_join(functional_data, by = c('name_accepted' = 'taxon_accepted')) %>%
  filter(nv_functional_gr == 'N-fixing feathermoss' & dead_status == 'FALSE') %>%
  group_by(site_visit_code) %>%
  summarize(nfeamos_cover_percent = sum(cover_percent)) %>%
  right_join(indicators, by = 'site_visit_code') %>%
  mutate(nfeamos_cover_percent = case_when(is.na(nfeamos_cover_percent) ~ 0,
                                           TRUE ~ nfeamos_cover_percent))

# Calculate Umbilicaria cover
indicators = vegetation_data %>%
  left_join(functional_data, by = c('name_accepted' = 'taxon_accepted')) %>%
  filter(taxon_genus == 'Umbilicaria' & dead_status == 'FALSE') %>%
  group_by(site_visit_code) %>%
  summarize(umbili_cover_percent = sum(cover_percent)) %>%
  right_join(indicators, by = 'site_visit_code') %>%
  mutate(umbili_cover_percent = case_when(is.na(umbili_cover_percent) ~ 0,
                                          TRUE ~ umbili_cover_percent))

# Calculate lichen cover
indicators = vegetation_data %>%
  left_join(functional_data, by = c('name_accepted' = 'taxon_accepted')) %>%
  filter(taxon_category == 'lichen' & dead_status == 'FALSE') %>%
  group_by(site_visit_code) %>%
  summarize(lichen_cover_percent = sum(cover_percent)) %>%
  right_join(indicators, by = 'site_visit_code') %>%
  mutate(lichen_cover_percent = case_when(is.na(lichen_cover_percent) ~ 0,
                                          TRUE ~ lichen_cover_percent))

# Calculate tussock cover (includes live and dead material from Eriophorum vaginatum and Eriophorum brachyantherum)
indicators = vegetation_data %>%
  left_join(functional_data, by = c('name_accepted' = 'taxon_accepted')) %>%
  filter(name_accepted == 'Eriophorum vaginatum' | name_accepted == 'Eriophorum brachyantherum') %>%
  group_by(site_visit_code) %>%
  summarize(tussock_cover_percent = sum(cover_percent)) %>%
  right_join(indicators, by = 'site_visit_code') %>%
  mutate(tussock_cover_percent = case_when(is.na(tussock_cover_percent) ~ 0,
                                          TRUE ~ tussock_cover_percent))

# Calculate Poaceae cover
indicators = vegetation_data %>%
  left_join(functional_data, by = c('name_accepted' = 'taxon_accepted')) %>%
  filter(taxon_family == 'Poaceae' & dead_status == 'FALSE') %>%
  group_by(site_visit_code) %>%
  summarize(poafam_cover_percent = sum(cover_percent)) %>%
  right_join(indicators, by = 'site_visit_code') %>%
  mutate(poafam_cover_percent = case_when(is.na(poafam_cover_percent) ~ 0,
                                          TRUE ~ poafam_cover_percent))

# Calculate Rosaceae cover
indicators = vegetation_data %>%
  left_join(functional_data, by = c('name_accepted' = 'taxon_accepted')) %>%
  filter(taxon_family == 'Rosaceae' & dead_status == 'FALSE') %>%
  group_by(site_visit_code) %>%
  summarize(rosfam_cover_percent = sum(cover_percent)) %>%
  right_join(indicators, by = 'site_visit_code') %>%
  mutate(rosfam_cover_percent = case_when(is.na(rosfam_cover_percent) ~ 0,
                                          TRUE ~ rosfam_cover_percent))

# Calculate Ericaceae cover
indicators = vegetation_data %>%
  left_join(functional_data, by = c('name_accepted' = 'taxon_accepted')) %>%
  filter(taxon_family == 'Ericaceae' & dead_status == 'FALSE') %>%
  group_by(site_visit_code) %>%
  summarize(erifam_cover_percent = sum(cover_percent)) %>%
  right_join(indicators, by = 'site_visit_code') %>%
  mutate(erifam_cover_percent = case_when(is.na(erifam_cover_percent) ~ 0,
                                          TRUE ~ erifam_cover_percent))

# Calculate Betula cover
indicators = vegetation_data %>%
  left_join(functional_data, by = c('name_accepted' = 'taxon_accepted')) %>%
  filter(taxon_genus == 'Betula' & dead_status == 'FALSE') %>%
  group_by(site_visit_code) %>%
  summarize(betula_cover_percent = sum(cover_percent)) %>%
  right_join(indicators, by = 'site_visit_code') %>%
  mutate(betula_cover_percent = case_when(is.na(betula_cover_percent) ~ 0,
                                          TRUE ~ betula_cover_percent))

# Calculate Salix cover
indicators = vegetation_data %>%
  left_join(functional_data, by = c('name_accepted' = 'taxon_accepted')) %>%
  filter(taxon_genus == 'Salix' & dead_status == 'FALSE') %>%
  group_by(site_visit_code) %>%
  summarize(salix_cover_percent = sum(cover_percent)) %>%
  right_join(indicators, by = 'site_visit_code') %>%
  mutate(salix_cover_percent = case_when(is.na(salix_cover_percent) ~ 0,
                                          TRUE ~ salix_cover_percent))

# Calculate low Salix
indicators = vegetation_data %>%
  left_join(functional_data, by = c('name_accepted' = 'taxon_accepted')) %>%
  filter((taxon_genus == 'Salix' & taxon_habit == 'shrub' & name_accepted != 'Salix alaxensis')
         & dead_status == 'FALSE') %>%
  group_by(site_visit_code) %>%
  summarize(lowsal_cover_percent = sum(cover_percent)) %>%
  right_join(indicators, by = 'site_visit_code') %>%
  mutate(lowsal_cover_percent = case_when(is.na(lowsal_cover_percent) ~ 0,
                                               TRUE ~ lowsal_cover_percent))

# Calculate dwarf Salix
indicators = vegetation_data %>%
  left_join(functional_data, by = c('name_accepted' = 'taxon_accepted')) %>%
  filter((taxon_genus == 'Salix' & (taxon_habit == 'dwarf shrub' | taxon_habit == 'dwarf shrub, shrub'))
         & dead_status == 'FALSE') %>%
  group_by(site_visit_code) %>%
  summarize(dwasal_cover_percent = sum(cover_percent)) %>%
  right_join(indicators, by = 'site_visit_code') %>%
  mutate(dwasal_cover_percent = case_when(is.na(dwasal_cover_percent) ~ 0,
                                                     TRUE ~ dwasal_cover_percent))

# Calculate dwarf Salix plus Dryas
indicators = vegetation_data %>%
  left_join(functional_data, by = c('name_accepted' = 'taxon_accepted')) %>%
  filter((taxon_genus == 'Dryas' |
            (taxon_genus == 'Salix' & (taxon_habit == 'dwarf shrub' | taxon_habit == 'dwarf shrub, shrub')))
         & dead_status == 'FALSE') %>%
  group_by(site_visit_code) %>%
  summarize(dwasal_dryas_cover_percent = sum(cover_percent)) %>%
  right_join(indicators, by = 'site_visit_code') %>%
  mutate(dwasal_dryas_cover_percent = case_when(is.na(dwasal_dryas_cover_percent) ~ 0,
                                         TRUE ~ dwasal_dryas_cover_percent))

# Calculate shrub cover
indicators = vegetation_data %>%
  left_join(functional_data, by = c('name_accepted' = 'taxon_accepted')) %>%
  filter((taxon_habit == 'dwarf shrub' | taxon_habit == 'dwarf shrub, shrub'
          | taxon_habit == 'dwarf shrub, shrub, tree' | taxon_habit == 'shrub') & dead_status == 'FALSE') %>%
  group_by(site_visit_code) %>%
  summarize(shrub_cover_percent = sum(cover_percent)) %>%
  right_join(indicators, by = 'site_visit_code') %>%
  mutate(shrub_cover_percent = case_when(is.na(shrub_cover_percent) ~ 0,
                                         TRUE ~ shrub_cover_percent))

# Calculate herbaceous cover
indicators = vegetation_data %>%
  left_join(functional_data, by = c('name_accepted' = 'taxon_accepted')) %>%
  filter((taxon_habit == 'forb' | taxon_habit == 'graminoid') & dead_status == 'FALSE') %>%
  group_by(site_visit_code) %>%
  summarize(herbac_cover_percent = sum(cover_percent)) %>%
  right_join(indicators, by = 'site_visit_code') %>%
  mutate(herbac_cover_percent = case_when(is.na(herbac_cover_percent) ~ 0,
                                         TRUE ~ herbac_cover_percent))

# Calculate dwarf shrub cover
shrub_join = shrub_data %>%
  filter(height_type == 'point-intercept mean') %>%
  filter(name_accepted != 'shrub') %>%
  select(site_visit_code, name_accepted, height_cm)
shrub_typical = shrub_join %>%
  group_by(name_accepted) %>%
  summarize(mean_cm = mean(height_cm))
indicators = vegetation_data %>%
  left_join(functional_data, by = c('name_accepted' = 'taxon_accepted')) %>%
  filter((taxon_habit == 'dwarf shrub' | taxon_habit == 'dwarf shrub, shrub'
          | taxon_habit == 'dwarf shrub, shrub, tree' | taxon_habit == 'shrub') & dead_status == 'FALSE') %>%
  left_join(shrub_join, by = c('site_visit_code' = 'site_visit_code', 'name_accepted' = 'name_accepted')) %>%
  left_join(shrub_typical, by = 'name_accepted') %>%
  mutate(height_cm = case_when(!is.na(height_cm) ~ height_cm,
                               is.na(height_cm) & !is.na(mean_cm) ~ mean_cm,
                               is.na(height_cm) & is.na(mean_cm)
                               & (taxon_habit == 'dwarf shrub' | taxon_habit == 'dwarf shrub, shrub') ~ 10,
                               is.na(height_cm) & is.na(mean_cm)
                               & (taxon_habit == 'shrub' | taxon_habit == 'dwarf shrub, shrub, tree') ~ 30,
                               TRUE ~ -999)) %>%
  filter(height_cm <= 20) %>%
  group_by(site_visit_code) %>%
  summarize(dwashr_cover_percent = sum(cover_percent)) %>%
  right_join(indicators, by = 'site_visit_code') %>%
  mutate(dwashr_cover_percent = case_when(is.na(dwashr_cover_percent) ~ 0,
                                         TRUE ~ dwashr_cover_percent))

# Calculate low shrub cover
indicators = vegetation_data %>%
  left_join(functional_data, by = c('name_accepted' = 'taxon_accepted')) %>%
  filter((taxon_habit == 'dwarf shrub' | taxon_habit == 'dwarf shrub, shrub'
          | taxon_habit == 'dwarf shrub, shrub, tree' | taxon_habit == 'shrub') & dead_status == 'FALSE') %>%
  left_join(shrub_join, by = c('site_visit_code' = 'site_visit_code', 'name_accepted' = 'name_accepted')) %>%
  left_join(shrub_typical, by = 'name_accepted') %>%
  mutate(height_cm = case_when(!is.na(height_cm) ~ height_cm,
                               is.na(height_cm) & !is.na(mean_cm) ~ mean_cm,
                               is.na(height_cm) & is.na(mean_cm)
                               & (taxon_habit == 'dwarf shrub' | taxon_habit == 'dwarf shrub, shrub') ~ 10,
                               is.na(height_cm) & is.na(mean_cm)
                               & (taxon_habit == 'shrub' | taxon_habit == 'dwarf shrub, shrub, tree') ~ 30,
                               TRUE ~ -999)) %>%
  filter(height_cm > 20 & height_cm <= 150) %>%
  group_by(site_visit_code) %>%
  summarize(lowshr_cover_percent = sum(cover_percent)) %>%
  right_join(indicators, by = 'site_visit_code') %>%
  mutate(lowshr_cover_percent = case_when(is.na(lowshr_cover_percent) ~ 0,
                                          TRUE ~ lowshr_cover_percent))

# Calculate tall shrub cover
indicators = vegetation_data %>%
  left_join(functional_data, by = c('name_accepted' = 'taxon_accepted')) %>%
  filter((taxon_habit == 'dwarf shrub' | taxon_habit == 'dwarf shrub, shrub'
          | taxon_habit == 'dwarf shrub, shrub, tree' | taxon_habit == 'shrub') & dead_status == 'FALSE') %>%
  left_join(shrub_join, by = c('site_visit_code' = 'site_visit_code', 'name_accepted' = 'name_accepted')) %>%
  left_join(shrub_typical, by = 'name_accepted') %>%
  mutate(height_cm = case_when(!is.na(height_cm) ~ height_cm,
                               is.na(height_cm) & !is.na(mean_cm) ~ mean_cm,
                               is.na(height_cm) & is.na(mean_cm)
                               & (taxon_habit == 'dwarf shrub' | taxon_habit == 'dwarf shrub, shrub') ~ 10,
                               is.na(height_cm) & is.na(mean_cm)
                               & (taxon_habit == 'shrub' | taxon_habit == 'dwarf shrub, shrub, tree') ~ 30,
                               TRUE ~ -999)) %>%
  filter(height_cm > 150) %>%
  group_by(site_visit_code) %>%
  summarize(talshr_cover_percent = sum(cover_percent)) %>%
  right_join(indicators, by = 'site_visit_code') %>%
  mutate(talshr_cover_percent = case_when(is.na(talshr_cover_percent) ~ 0,
                                          TRUE ~ talshr_cover_percent))

# Calculate tussock:wetland sedge ratio
indicators = indicators %>%
  mutate(tussock_wetsed_ratio =
           tussock_cover_percent / (tussock_cover_percent + wetsed_cover_percent + 0.001)) %>%
  mutate(tussock_wetsed_ratio = round(tussock_wetsed_ratio, 2))

# Calculate Eriophorum vaginatum cover
indicators = vegetation_data %>%
  left_join(functional_data, by = c('name_accepted' = 'taxon_accepted')) %>%
  filter(name_accepted == 'Eriophorum vaginatum' & dead_status == 'FALSE') %>%
  group_by(site_visit_code) %>%
  summarize(erivag_cover_percent = sum(cover_percent)) %>%
  right_join(indicators, by = 'site_visit_code') %>%
  mutate(erivag_cover_percent = case_when(is.na(erivag_cover_percent) ~ 0,
                                          TRUE ~ erivag_cover_percent))

# Calculate Rhododendron tomentosum cover
indicators = vegetation_data %>%
  left_join(functional_data, by = c('name_accepted' = 'taxon_accepted')) %>%
  filter((name_accepted == 'Rhododendron tomentosum' | name_accepted == 'Rhododendron tomentosum ssp. decumbens')
         & dead_status == 'FALSE') %>%
  group_by(site_visit_code) %>%
  summarize(rhotom_cover_percent = sum(cover_percent)) %>%
  right_join(indicators, by = 'site_visit_code') %>%
  mutate(rhotom_cover_percent = case_when(is.na(rhotom_cover_percent) ~ 0,
                                          TRUE ~ rhotom_cover_percent))

# Calculate Puccinellia phryganodes cover
indicators = vegetation_data %>%
  left_join(functional_data, by = c('name_accepted' = 'taxon_accepted')) %>%
  filter(name_accepted == 'Puccinellia phryganodes' & dead_status == 'FALSE') %>%
  group_by(site_visit_code) %>%
  summarize(pucphr_cover_percent = sum(cover_percent)) %>%
  right_join(indicators, by = 'site_visit_code') %>%
  mutate(pucphr_cover_percent = case_when(is.na(pucphr_cover_percent) ~ 0,
                                          TRUE ~ pucphr_cover_percent))

# Calculate Vaccinium vitis-idaea cover
indicators = vegetation_data %>%
  left_join(functional_data, by = c('name_accepted' = 'taxon_accepted')) %>%
  filter(name_accepted == 'Vaccinium vitis-idaea' & dead_status == 'FALSE') %>%
  group_by(site_visit_code) %>%
  summarize(vacvit_cover_percent = sum(cover_percent)) %>%
  right_join(indicators, by = 'site_visit_code') %>%
  mutate(vacvit_cover_percent = case_when(is.na(vacvit_cover_percent) ~ 0,
                                          TRUE ~ vacvit_cover_percent))


# Calculate Betula nana cover
indicators = vegetation_data %>%
  left_join(functional_data, by = c('name_accepted' = 'taxon_accepted')) %>%
  filter((name_accepted == 'Betula nana' | name_accepted == 'Betula nana ssp. exilis')
         & dead_status == 'FALSE') %>%
  group_by(site_visit_code) %>%
  summarize(betnan_cover_percent = sum(cover_percent)) %>%
  right_join(indicators, by = 'site_visit_code') %>%
  mutate(betnan_cover_percent = case_when(is.na(betnan_cover_percent) ~ 0,
                                          TRUE ~ betnan_cover_percent))

# Calculate Leymus cover
indicators = vegetation_data %>%
  left_join(functional_data, by = c('name_accepted' = 'taxon_accepted')) %>%
  filter(taxon_genus == 'Leymus' & dead_status == 'FALSE') %>%
  group_by(site_visit_code) %>%
  summarize(leymus_cover_percent = sum(cover_percent)) %>%
  right_join(indicators, by = 'site_visit_code') %>%
  mutate(leymus_cover_percent = case_when(is.na(leymus_cover_percent) ~ 0,
                                          TRUE ~ leymus_cover_percent))

# Calculate Salix pulchra cover
indicators = vegetation_data %>%
  left_join(functional_data, by = c('name_accepted' = 'taxon_accepted')) %>%
  filter(name_accepted == 'Salix pulchra' & dead_status == 'FALSE') %>%
  group_by(site_visit_code) %>%
  summarize(salpul_cover_percent = sum(cover_percent)) %>%
  right_join(indicators, by = 'site_visit_code') %>%
  mutate(salpul_cover_percent = case_when(is.na(salpul_cover_percent) ~ 0,
                                          TRUE ~ salpul_cover_percent))

# Calculate Stellaria humifusa cover
indicators = vegetation_data %>%
  left_join(functional_data, by = c('name_accepted' = 'taxon_accepted')) %>%
  filter(name_accepted == 'Stellaria humifusa' & dead_status == 'FALSE') %>%
  group_by(site_visit_code) %>%
  summarize(stehum_cover_percent = sum(cover_percent)) %>%
  right_join(indicators, by = 'site_visit_code') %>%
  mutate(stehum_cover_percent = case_when(is.na(stehum_cover_percent) ~ 0,
                                          TRUE ~ stehum_cover_percent))

# Calculate Aulacomnium cover
indicators = vegetation_data %>%
  left_join(functional_data, by = c('name_accepted' = 'taxon_accepted')) %>%
  filter(taxon_genus == 'Aulacomnium' & dead_status == 'FALSE') %>%
  group_by(site_visit_code) %>%
  summarize(aulaco_cover_percent = sum(cover_percent)) %>%
  right_join(indicators, by = 'site_visit_code') %>%
  mutate(aulaco_cover_percent = case_when(is.na(aulaco_cover_percent) ~ 0,
                                          TRUE ~ aulaco_cover_percent))

# Calculate Carex aquatilis cover
indicators = vegetation_data %>%
  left_join(functional_data, by = c('name_accepted' = 'taxon_accepted')) %>%
  filter(name_accepted == 'Carex aquatilis' & dead_status == 'FALSE') %>%
  group_by(site_visit_code) %>%
  summarize(caraqu_cover_percent = sum(cover_percent)) %>%
  right_join(indicators, by = 'site_visit_code') %>%
  mutate(caraqu_cover_percent = case_when(is.na(caraqu_cover_percent) ~ 0,
                                          TRUE ~ caraqu_cover_percent))

# Calculate Dryas ajanensis cover
indicators = vegetation_data %>%
  left_join(functional_data, by = c('name_accepted' = 'taxon_accepted')) %>%
  filter((name_accepted == 'Dryas ajanensis' | name_accepted == 'Dryas ajanensis ssp. beringensis')
         & dead_status == 'FALSE') %>%
  group_by(site_visit_code) %>%
  summarize(dryaja_cover_percent = sum(cover_percent)) %>%
  right_join(indicators, by = 'site_visit_code') %>%
  mutate(dryaja_cover_percent = case_when(is.na(dryaja_cover_percent) ~ 0,
                                          TRUE ~ dryaja_cover_percent))

# Calculate Dicranum cover
indicators = vegetation_data %>%
  left_join(functional_data, by = c('name_accepted' = 'taxon_accepted')) %>%
  filter(taxon_genus == 'Dicranum' & dead_status == 'FALSE') %>%
  group_by(site_visit_code) %>%
  summarize(dicran_cover_percent = sum(cover_percent)) %>%
  right_join(indicators, by = 'site_visit_code') %>%
  mutate(dicran_cover_percent = case_when(is.na(dicran_cover_percent) ~ 0,
                                          TRUE ~ dicran_cover_percent))

# Calculate Salix alaxensis cover
indicators = vegetation_data %>%
  left_join(functional_data, by = c('name_accepted' = 'taxon_accepted')) %>%
  filter(name_accepted == 'Salix alaxensis' & dead_status == 'FALSE') %>%
  group_by(site_visit_code) %>%
  summarize(salala_cover_percent = sum(cover_percent)) %>%
  right_join(indicators, by = 'site_visit_code') %>%
  mutate(salala_cover_percent = case_when(is.na(salala_cover_percent) ~ 0,
                                          TRUE ~ salala_cover_percent))

# Calculate Carex chordorrhiza cover
indicators = vegetation_data %>%
  left_join(functional_data, by = c('name_accepted' = 'taxon_accepted')) %>%
  filter(name_accepted == 'Carex chordorrhiza' & dead_status == 'FALSE') %>%
  group_by(site_visit_code) %>%
  summarize(carcho_cover_percent = sum(cover_percent)) %>%
  right_join(indicators, by = 'site_visit_code') %>%
  mutate(carcho_cover_percent = case_when(is.na(carcho_cover_percent) ~ 0,
                                          TRUE ~ carcho_cover_percent))

# Calculate Arctous rubra cover
indicators = vegetation_data %>%
  left_join(functional_data, by = c('name_accepted' = 'taxon_accepted')) %>%
  filter(name_accepted == 'Arctous rubra' & dead_status == 'FALSE') %>%
  group_by(site_visit_code) %>%
  summarize(arcrub_cover_percent = sum(cover_percent)) %>%
  right_join(indicators, by = 'site_visit_code') %>%
  mutate(arcrub_cover_percent = case_when(is.na(arcrub_cover_percent) ~ 0,
                                          TRUE ~ arcrub_cover_percent))

# Calculate Scorpidium cover
indicators = vegetation_data %>%
  left_join(functional_data, by = c('name_accepted' = 'taxon_accepted')) %>%
  filter(taxon_genus == 'Scorpidium' & dead_status == 'FALSE') %>%
  group_by(site_visit_code) %>%
  summarize(scorpi_cover_percent = sum(cover_percent)) %>%
  right_join(indicators, by = 'site_visit_code') %>%
  mutate(scorpi_cover_percent = case_when(is.na(scorpi_cover_percent) ~ 0,
                                          TRUE ~ scorpi_cover_percent))

# Calculate Oxytropis bryophila cover
indicators = vegetation_data %>%
  left_join(functional_data, by = c('name_accepted' = 'taxon_accepted')) %>%
  filter(name_accepted == 'Oxytropis bryophila' & dead_status == 'FALSE') %>%
  group_by(site_visit_code) %>%
  summarize(oxybry_cover_percent = sum(cover_percent)) %>%
  right_join(indicators, by = 'site_visit_code') %>%
  mutate(oxybry_cover_percent = case_when(is.na(oxybry_cover_percent) ~ 0,
                                          TRUE ~ oxybry_cover_percent))

# Calculate Equisetum arvense cover
indicators = vegetation_data %>%
  left_join(functional_data, by = c('name_accepted' = 'taxon_accepted')) %>%
  filter(name_accepted == 'Equisetum arvense' & dead_status == 'FALSE') %>%
  group_by(site_visit_code) %>%
  summarize(equarv_cover_percent = sum(cover_percent)) %>%
  right_join(indicators, by = 'site_visit_code') %>%
  mutate(equarv_cover_percent = case_when(is.na(equarv_cover_percent) ~ 0,
                                          TRUE ~ equarv_cover_percent))

# Calculate Cladonia cover
indicators = vegetation_data %>%
  left_join(functional_data, by = c('name_accepted' = 'taxon_accepted')) %>%
  filter(taxon_genus == 'Cladonia' & dead_status == 'FALSE') %>%
  group_by(site_visit_code) %>%
  summarize(cladon_cover_percent = sum(cover_percent)) %>%
  right_join(indicators, by = 'site_visit_code') %>%
  mutate(cladon_cover_percent = case_when(is.na(cladon_cover_percent) ~ 0,
                                          TRUE ~ cladon_cover_percent))

# Calculate Rubus chamaemorus cover
indicators = vegetation_data %>%
  left_join(functional_data, by = c('name_accepted' = 'taxon_accepted')) %>%
  filter(name_accepted == 'Rubus chamaemorus' & dead_status == 'FALSE') %>%
  group_by(site_visit_code) %>%
  summarize(rubcha_cover_percent = sum(cover_percent)) %>%
  right_join(indicators, by = 'site_visit_code') %>%
  mutate(rubcha_cover_percent = case_when(is.na(rubcha_cover_percent) ~ 0,
                                          TRUE ~ rubcha_cover_percent))

# Calculate Salix phlebophylla cover
indicators = vegetation_data %>%
  left_join(functional_data, by = c('name_accepted' = 'taxon_accepted')) %>%
  filter(name_accepted == 'Salix phlebophylla' & dead_status == 'FALSE') %>%
  group_by(site_visit_code) %>%
  summarize(salphl_cover_percent = sum(cover_percent)) %>%
  right_join(indicators, by = 'site_visit_code') %>%
  mutate(salphl_cover_percent = case_when(is.na(salphl_cover_percent) ~ 0,
                                          TRUE ~ salphl_cover_percent))

# Calculate Alectoria cover
indicators = vegetation_data %>%
  left_join(functional_data, by = c('name_accepted' = 'taxon_accepted')) %>%
  filter(taxon_genus == 'Alectoria' & dead_status == 'FALSE') %>%
  group_by(site_visit_code) %>%
  summarize(alecto_cover_percent = sum(cover_percent)) %>%
  right_join(indicators, by = 'site_visit_code') %>%
  mutate(alecto_cover_percent = case_when(is.na(alecto_cover_percent) ~ 0,
                                          TRUE ~ alecto_cover_percent))

# Calculate Carex subspathacea cover
indicators = vegetation_data %>%
  left_join(functional_data, by = c('name_accepted' = 'taxon_accepted')) %>%
  filter(name_accepted == 'Carex subspathacea' & dead_status == 'FALSE') %>%
  group_by(site_visit_code) %>%
  summarize(carsub_cover_percent = sum(cover_percent)) %>%
  right_join(indicators, by = 'site_visit_code') %>%
  mutate(carsub_cover_percent = case_when(is.na(carsub_cover_percent) ~ 0,
                                          TRUE ~ carsub_cover_percent))

# Calculate vascular species richness
indicators = vegetation_data %>%
  left_join(functional_data, by = c('name_accepted' = 'taxon_accepted')) %>%
  filter(nv_functional_gr == 'vascular') %>%
  group_by(site_visit_code) %>%
  summarize(species_richness = n()) %>%
  right_join(indicators, by = 'site_visit_code')

# Join strata table
output_data = strata_data %>%
  left_join(indicators, by = 'site_visit_code') %>%
  mutate(shrub_cover_percent = case_when(is.na(shrub_cover_percent) ~ 0,
                                         TRUE ~ shrub_cover_percent)) %>%
  mutate(herbac_cover_percent = case_when(is.na(herbac_cover_percent) ~ 0,
                                          TRUE ~ herbac_cover_percent)) %>%
  mutate(organic_depth_cm = case_when(is.na(organic_depth_cm)
                                      & (stratum_code == 'AB' | stratum_code == 'ADST' | stratum_code == 'AFS'
                                         | stratum_code == 'CPID') ~ 0,
                                      TRUE ~ organic_depth_cm)) %>%
  mutate(depth_moss_duff_cm = case_when(site_visit_code == 'AFPD-31_20130730' ~ 5,
                                        site_visit_code == 'CPBWM-26_20130731' ~ 0,
                                        site_visit_code == 'CPBWM-31_20130725' ~ 0,
                                        site_visit_code == 'CPBWM-51_20140726' ~ 0,
                                        site_visit_code == 'CPBWM-52_20140721' ~ 0,
                                        site_visit_code == 'FWMM-24_20130728' ~ 0,
                                        site_visit_code == 'FWMM-59_20140722' ~ 0,
                                        site_visit_code == 'FWMM-80_20170728' ~ 0,
                                        site_visit_code == 'GMT2-052_20190805' ~ 0,
                                        site_visit_code == 'GMT2-090_20190809' ~ 0,
                                        site_visit_code == 'GMT2-096_20190801' ~ 0,
                                        site_visit_code == 'GMT2-131_20190806' ~ 0,
                                        site_visit_code == 'GMT2-136_20190808' ~ 0,
                                        site_visit_code == 'SSBWM-53_20140728' ~ 0,
                                        site_visit_code == 'SSBWM-54_20140724' ~ 0,
                                        site_visit_code == 'TMCW-55B_20140725' ~ 0,
                                        TRUE ~ depth_moss_duff_cm))

#### CREATE LONG FORM DATA
####------------------------------

longform_data = output_data %>%
  mutate(depth_active_layer_cm = case_when(is.na(depth_active_layer_cm) ~ 200,
                                           TRUE ~ depth_active_layer_cm)) %>%
  mutate(shrub_mean_height_cm = case_when(is.na(shrub_mean_height_cm) ~ 0,
                                          TRUE ~ shrub_mean_height_cm)) %>%
  mutate(shrub_max_height_cm = case_when(is.na(shrub_max_height_cm) ~ 0,
                                         TRUE ~ shrub_max_height_cm)) %>%
  mutate(herbac_mean_height_cm = case_when(is.na(herbac_mean_height_cm) ~ 0,
                                           TRUE ~ herbac_mean_height_cm)) %>%
  mutate(herbac_max_height_cm = case_when(is.na(herbac_max_height_cm) ~ 0,
                                          TRUE ~ herbac_max_height_cm)) %>%
  mutate(shrub_herbac_height_ratio = case_when(is.na(shrub_herbac_height_ratio) ~ 0,
                                               TRUE ~ shrub_herbac_height_ratio)) %>%
  select(-site_code, -stratum_code, -stratum_name, -physiography, -plot_category,) %>%
  pivot_longer(!site_visit_code, names_to = 'indicator', values_to = 'value') %>%
  left_join(strata_data, by = 'site_visit_code') %>%
  left_join(site_visit_data, by = 'site_visit_code') %>%
  select(site_code, site_visit_code, stratum_code, stratum_name, physiography, plot_category,
         latitude_dd, longitude_dd, indicator, value)

#### EXPORT DATA
####------------------------------

# Export strata table
write.csv(output_data, file = indicators_output, fileEncoding = 'UTF-8', row.names = FALSE)
write.csv(longform_data, file = longform_output, fileEncoding = 'UTF-8', row.names = FALSE)
