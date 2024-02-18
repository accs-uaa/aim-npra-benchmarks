# -*- coding: utf-8 -*-
# ---------------------------------------------------------------------------
# Create strata table
# Author: Timm Nawrocki, Alaska Center for Conservation Science
# Last Updated: 2024-02-06
# Usage: Script should be executed in R 4.0.0+.
# Description: "Create strata table" creates a table of sites and site visits parsed by stratum and physiography.
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
strata_input = path(data_folder, 'Data/Data_Input/strata/sites_by_strata.csv')
metadata_input = path(data_folder, 'Data/Data_Input/summary/AIM_Strata_Site_Species_forPCORD.xlsx')

# Define output files
strata_output = path(data_folder, 'Data/Data_Output/strata/AIM_NPRA_Strata.csv')

# Import database connection function
connection_script = path(akveg_repository, 'package_DataProcessing', 'connect_database_postgresql.R')
source(connection_script)

# Create a connection to the AKVEG PostgreSQL database
authentication = path(credentials_folder, 'authentication_akveg_private.csv')
database_connection = connect_database_postgresql(authentication)

# Read site visit data from AKVEG Database
site_visit_query = read_file(site_visit_file)
site_visit_data = as_tibble(dbGetQuery(database_connection, site_visit_query))

# Read metadata table
metadata_data = read_xlsx(metadata_input, sheet='import_site_v_veg_metrics') %>%
  select(site_code, Stratum_Lump, Analysis_Cat) %>%
  rename(physiography = Stratum_Lump,
         plot_category = Analysis_Cat) %>%
  mutate(plot_category = case_when(plot_category == 'Homogenous' ~ 'homogeneous',
                                   plot_category == 'Heterogenous' ~ 'heterogeneous',
                                   TRUE ~ plot_category)) %>%
  mutate(plot_category = str_to_lower(plot_category))

# Join strata tables
strata_data = read_csv(strata_input) %>%
  left_join(metadata_data, by = 'site_code') %>%
  left_join(site_visit_data, by = 'site_code') %>%
  select(site_code, site_visit_code, stratum_name, stratum_code, physiography, plot_category) %>%
  mutate(stratum_name = case_when(stratum_name == 'Arctic Floodplain Poorly Drained' ~ 'Arctic Floodplain Wetland',
                                  TRUE ~ stratum_name)) %>%
  mutate(stratum_code = case_when(stratum_code == 'AFPD' ~ 'AFW',
                                  TRUE ~ stratum_code))

# Export strata table
write.csv(strata_data, file = strata_output, fileEncoding = 'UTF-8', row.names = FALSE)