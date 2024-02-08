# -*- coding: utf-8 -*-
# ---------------------------------------------------------------------------
# Prepare functional groups
# Author: Timm Nawrocki, Alaska Center for Conservation Science
# Last Updated: 2024-02-06
# Usage: Script should be executed in R 4.0.0+.
# Description: "Prepare functional groups" creates a table of functional group to species relationships.
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
taxon_file = path(query_folder, 'npra_00_taxon_query.sql')
strata_input = path(data_folder, 'Data/Data_Input/strata/sites_by_strata.csv')
metadata_input = path(data_folder, 'Data/Data_Input/summary/AIM_Strata_Site_Species_forPCORD.xlsx')

# Define output files
taxon_output = path(data_folder, 'Data/Data_Output/functional_groups/AIM_NPRA_Functional_Groups.csv')

# Import database connection function
connection_script = path(akveg_repository, 'package_DataProcessing', 'connect_database_postgresql.R')
source(connection_script)

# Create a connection to the AKVEG PostgreSQL database
authentication = path(credentials_folder, 'authentication_akveg_private.csv')
database_connection = connect_database_postgresql(authentication)

# Read taxon table
taxon_query = read_file(taxon_file)
taxon_data = as_tibble(dbGetQuery(database_connection, taxon_query))

# Read metadata table
metadata_data = read_xlsx(metadata_input, sheet='AIM_Strata_Site_Species_Edit') %>%
  distinct(taxon_accepted_code, wetland_status, nv_functional_gr)

# Join metadata to taxon table
taxon_data = taxon_data %>%
  left_join(metadata_data, by = 'taxon_accepted_code') %>%
  mutate(nv_functional_gr = case_when(taxon_category != 'lichen' & taxon_category != 'liverwort' & taxon_category != 'moss'
                                      ~ 'vascular',
                                      taxon_accepted == 'Amblystegium serpens' ~ 'turf moss',
                                      taxon_accepted == 'Campylium' ~ 'aquatic moss',
                                      taxon_accepted == 'Sanionia' ~ 'feathermoss',
                                      taxon_accepted == 'Sanionia uncinata' ~ 'feathermoss',
                                      taxon_family == 'Brachytheciaceae' ~ 'feathermoss',
                                      taxon_family == 'Bryaceae' ~ 'turf moss',
                                      taxon_family == 'Calliergonaceae' ~ 'aquatic moss',
                                      taxon_family == 'Cephaloziaceae' ~ 'liverwort',
                                      taxon_accepted == 'Cladonia albonigra' ~ 'forage lichen',
                                      taxon_accepted == 'Cladonia fimbriata' ~ 'forage lichen',
                                      taxon_accepted == 'Cladonia stellaris' ~ 'forage lichen',
                                      taxon_accepted == 'Conocephalum salebrosum' ~ 'thalloid liverwort',
                                      taxon_family == 'Dicranaceae' ~ 'turf moss',
                                      taxon_family == 'Encalyptaceae' ~ 'turf moss',
                                      taxon_family == 'Entodontaceae' ~ 'feathermoss',
                                      taxon_family == 'Fissidentaceae' ~ 'turf moss',
                                      taxon_family == 'Grimmiaceae' ~ 'turf moss',
                                      taxon_family == 'Hypnaceae' ~ 'feathermoss',
                                      taxon_family == 'Lobariaceae' ~ 'foliose lichen',
                                      taxon_accepted == 'Marchantia polymorpha' ~ 'thalloid liverwort',
                                      taxon_accepted == 'Meesia triquetra' ~ 'other moss',
                                      taxon_family == 'Mniaceae' ~ 'other moss',
                                      taxon_accepted == 'Mylia anomala' ~ 'liverwort',
                                      taxon_accepted == 'Ochrolechia frigida' ~ 'crustose lichen',
                                      taxon_genus == 'Bryocaulon' ~ 'forage lichen',
                                      taxon_genus == 'Bryoria' ~ 'forage lichen',
                                      taxon_genus == 'Cetraria' ~ 'forage lichen',
                                      taxon_genus == 'Hypogymnia' ~ 'foliose lichen',
                                      taxon_genus == 'Masonhalea' ~ 'foliose lichen',
                                      taxon_genus == 'Parmelia' ~ 'foliose lichen',
                                      taxon_genus == 'Vulpicida' ~ 'foliose lichen',
                                      taxon_genus == 'Peltigera' ~ 'N-fixing foliose lichen',
                                      taxon_family == 'Plagiotheciaceae' ~ 'turf moss',
                                      taxon_family == 'Polytrichaceae' ~ 'turf moss',
                                      taxon_accepted == 'Ropalospora lugubris' ~ 'crustose lichen',
                                      taxon_genus == 'Scapania' ~ 'liverwort',
                                      taxon_genus == 'Sphaerophorus' ~ 'forage lichen',
                                      taxon_genus == 'Sphagnum' ~ 'Sphagnum',
                                      taxon_family == 'Splachnaceae' ~ 'other moss',
                                      taxon_family == 'Stereocaulaceae' ~ 'N-fixing fruticose lichen',
                                      taxon_accepted == 'Thuidium recognitum' ~ 'feathermoss',
                                      taxon_accepted == 'Lepra dactylina' ~ 'other lichen',
                                      taxon_accepted == 'Ceratodon purpureus' ~ 'turf moss',
                                      taxon_accepted == 'Leptobryum pyriforme' ~ 'turf moss',
                                      taxon_genus == 'Dactylina' ~ 'other lichen',
                                      TRUE ~ nv_functional_gr)) %>%
  mutate(wetland_sedge = case_when(taxon_accepted == 'Carex adelostoma' ~ 'wetland sedge',
                                   taxon_accepted == 'Carex aquatilis' ~ 'wetland sedge',
                                   taxon_accepted == 'Carex arcta' ~ 'wetland sedge',
                                   taxon_accepted == 'Carex bicolor' ~ 'wetland sedge',
                                   taxon_accepted == 'Carex chordorrhiza' ~ 'wetland sedge',
                                   taxon_accepted == 'Carex diandra' ~ 'wetland sedge',
                                   taxon_accepted == 'Carex echinata' ~ 'wetland sedge',
                                   taxon_accepted == 'Carex enanderi' ~ 'wetland sedge',
                                   taxon_accepted == 'Carex glareosa' ~ 'wetland sedge',
                                   taxon_accepted == 'Carex glareosa ssp. glareosa' ~ 'wetland sedge',
                                   taxon_accepted == 'Carex gynocrates' ~ 'wetland sedge',
                                   taxon_accepted == 'Carex holostoma' ~ 'wetland sedge',
                                   taxon_accepted == 'Carex interior' ~ 'wetland sedge',
                                   taxon_accepted == 'Carex kelloggii' ~ 'wetland sedge',
                                   taxon_accepted == 'Carex lachenalii' ~ 'wetland sedge',
                                   taxon_accepted == 'Carex lasiocarpa' ~ 'wetland sedge',
                                   taxon_accepted == 'Carex laxa' ~ 'wetland sedge',
                                   taxon_accepted == 'Carex leptalea' ~ 'wetland sedge',
                                   taxon_accepted == 'Carex limosa' ~ 'wetland sedge',
                                   taxon_accepted == 'Carex livida' ~ 'wetland sedge',
                                   taxon_accepted == 'Carex lyngbyei' ~ 'wetland sedge',
                                   taxon_accepted == 'Carex marina' ~ 'wetland sedge',
                                   taxon_accepted == 'Carex marina ssp. marina' ~ 'wetland sedge',
                                   taxon_accepted == 'Carex membranacea' ~ 'wetland sedge',
                                   taxon_accepted == 'Carex microglochin' ~ 'wetland sedge',
                                   taxon_accepted == 'Carex pauciflora' ~ 'wetland sedge',
                                   taxon_accepted == 'Carex paupercula' ~ 'wetland sedge',
                                   taxon_accepted == 'Carex pluriflora' ~ 'wetland sedge',
                                   taxon_accepted == 'Carex rariflora' ~ 'wetland sedge',
                                   taxon_accepted == 'Carex rostrata' ~ 'wetland sedge',
                                   taxon_accepted == 'Carex rotundata' ~ 'wetland sedge',
                                   taxon_accepted == 'Carex saxatilis' ~ 'wetland sedge',
                                   taxon_accepted == 'Carex saxatilis ssp. laxa' ~ 'wetland sedge',
                                   taxon_accepted == 'Carex sitchensis' ~ 'wetland sedge',
                                   taxon_accepted == 'Carex utriculata' ~ 'wetland sedge',
                                   taxon_accepted == 'Carex vaginata' ~ 'wetland sedge',
                                   taxon_accepted == 'Carex viridula ssp. viridula' ~ 'wetland sedge',
                                   taxon_accepted == 'Eriophorum angustifolium' ~ 'wetland sedge',
                                   taxon_accepted == 'Eriophorum chamissonis' ~ 'wetland sedge',
                                   taxon_accepted == 'Eriophorum gracile' ~ 'wetland sedge',
                                   taxon_accepted == 'Eriophorum gracile ssp. gracile' ~ 'wetland sedge',
                                   taxon_accepted == 'Eriophorum komarovii' ~ 'wetland sedge',
                                   taxon_accepted == 'Eriophorum ?medium' ~ 'wetland sedge',
                                   taxon_accepted == 'Eriophorum ?medium ssp. album' ~ 'wetland sedge',
                                   taxon_accepted == 'Eriophorum russeolum' ~ 'wetland sedge',
                                   taxon_accepted == 'Eriophorum russeolum ssp. leiocarpum' ~ 'wetland sedge',
                                   taxon_accepted == 'Eriophorum scheuchzeri' ~ 'wetland sedge',
                                   taxon_accepted == 'Eriophorum scheuchzeri ssp. arcticum' ~ 'wetland sedge',
                                   taxon_accepted == 'Eriophorum scheuchzeri ssp. scheuchzeri' ~ 'wetland sedge',
                                   taxon_accepted == 'Eriophorum triste' ~ 'wetland sedge',
                                   taxon_accepted == 'Eriophorum viridicarinatum' ~ 'wetland sedge',
                                   TRUE ~ 'none'))

# Export strata table
write.csv(taxon_data, file = taxon_output, fileEncoding = 'UTF-8', row.names = FALSE)
