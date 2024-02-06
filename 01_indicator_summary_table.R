# -*- coding: utf-8 -*-
# ---------------------------------------------------------------------------
# Summarize AIM indicators
# Author: Timm Nawrocki, Alaska Center for Conservation Science
# Last Updated: 2024-02-06
# Usage: Script should be executed in R 4.0.0+.
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
akveg_repository = 'C:/Users/timmn/Documents/Repositories/akveg-database'
benchmark_repository= 'C:/Users/timmn/Documents/Repositories/aim-npra-benchmarks'
query_folder = path(benchmark_repository, 'queries')
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

# Define output files
output_file = path(data_folder, 'AIM_NPRA_Indicator_Summary.csv')

# Import database connection function
connection_script = path(akveg_repository, 'package_DataProcessing', 'connect_database_postgresql.R')
source(connection_script)

# Create a connection to the AKVEG PostgreSQL database
authentication = path(credentials_folder, 'authentication_akveg_private.csv')
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



query_taxon = 'SELECT * FROM taxon_all'
query_type = 'SELECT * FROM cover_type'
query_class = 'SELECT * FROM shrub_class'
query_height = 'SELECT * FROM height_type'
taxon_data = as_tibble(dbGetQuery(database_connection, query_taxon))
type_data = as_tibble(dbGetQuery(database_connection, query_type))
class_data = as_tibble(dbGetQuery(database_connection, query_class))
height_data = as_tibble(dbGetQuery(database_connection, query_height))