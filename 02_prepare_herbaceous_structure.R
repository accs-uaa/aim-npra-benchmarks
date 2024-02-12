# -*- coding: utf-8 -*-
# ---------------------------------------------------------------------------
# "Extract Herbaceous Height Data from AIM 2021 Data"
# Author: Amanda Droghini, Alaska Center for Conservation Science
# Last Updated: 2024-02-06
# Usage: Must be executed in R version 4.3.2+.
# Description: "Extract Herbaceous Height Data from AIM 2021 Data" summarizes data from line-point intercepts to obtain species-specific heights (98th percentile and mean) for each site of interest. The script also formats site codes, merges USDA plant codes with accepted taxonomic names, and corrects errors in the original data. Initial data tables were extracted from BLM's 2022 TerrADat geodatabase in ArcGIS Pro.
# ---------------------------------------------------------------------------

rm(list=ls())

# Load packages ----
library(dplyr)
library(fs)
library(readr)
library(readxl)
library(RPostgres)
library(stringr)
library(tidyr)

# Define directories ----
drive = "D:"
project_folder = path(drive, "ACCS_Work/Projects/VegetationEcology/AKVEG_Database/Data")
plot_folder = path(project_folder,"Data_Plots/32_aim_various_2021")
data_folder = path(plot_folder, "source/extracted_tables")
template_folder = path(project_folder, "Data_Entry")

# Set repository directory
repository = 'C:/ACCS_Work/GitHub/akveg-database-public'

# Define inputs ----
input_cover = path(data_folder, "tbl_lpidetail_2022.csv")
input_projects = path(data_folder, "terradat_2022.csv")
input_template = path(template_folder, "15_herbaceous_structure.xlsx")
input_sites = path(drive, "ACCS_Work/Projects/VegetationEcology/BLM_AIM_NPRA_Benchmarks/temp_files/sites_by_strata.csv") # File from colleague with a list of sites to subset
input_taxonomy = path(project_folder,"Tables_Taxonomy/USDA_Plants/plants_20210611.csv")

# Define outputs ----
output_heights = path(drive, "ACCS_Work/Projects/VegetationEcology/BLM_AIM_NPRA_Benchmarks", "15_herbaceousstructure_aimvarious2021.csv")

# Connect to AKVEG PostgreSQL database ----

# Import database connection function
connection_script = paste(repository,
                          'package_DataProcessing',
                          'connectDatabasePostGreSQL.R',
                          sep = '/')
source(connection_script)

authentication = path(
  "C:/ACCS_Work/Servers_Websites/Credentials/accs-postgresql/authentication_akveg.csv"
)

akveg_connection = connect_database_postgresql(authentication)


# Read in data ----
plot_cover = read_csv(file=input_cover)
projects = read_csv(file=input_projects, col_select=c("PrimaryKey",
                                                      "ProjectName",
                                                      "PlotID", 
                                                      "DateVisited"))
sites = read_csv(input_sites)
template = colnames(read_xlsx(path=input_template))
plant_codes = read_csv(input_taxonomy, 
                       col_select=c("code_plants","name_plants"))

# Read PostgreSQL taxonomy tables
query_all = 'SELECT * FROM taxon_all'
taxa_all = as_tibble(dbGetQuery(akveg_connection, query_all))

# Read PostgreSQL vegetation cover table
query_cover = 'SELECT * FROM vegetation_cover'
cover_all = as_tibble(dbGetQuery(akveg_connection, query_cover))

# Read PostgreSQL site visit table
query_visit = 'SELECT site_visit_code, site_code FROM site_visit'
visit_all = as_tibble(dbGetQuery(akveg_connection, query_visit))

# Format taxonomy table ----
taxa_all = taxa_all %>% 
  select(taxon_code,taxon_name)

# Create site_code variable ----

# Join project info to plot_cover info
plot_cover = left_join(plot_cover,projects,by="PrimaryKey") # Can ignore many-to-many warning: both rows refer to sites in WY

# Standardize plot IDs
plot_cover = plot_cover %>%
  mutate(PlotID = case_when(PlotID == "Plot43_CPBWM_2000" ~ "Plot_43_CPBWM_2000",
                            PlotID == "Plot47_CPHCP_2000" ~ "Plot_47_CPHCP_2000",
                            PlotID == "Plot50_AFS_2000" ~ "Plot_50_AFS_2000",
                            PlotID == "plot133-cpbwm_507_1007" ~ "plot_133-cpbwm_507_1007",
                            PlotID == "Plot52_AFS-2000" ~ "Plot_52_AFS-2000",
                            .default = PlotID)) %>% 
  mutate(PlotID = case_when(ProjectName=="Alaska Arctic DO 2019" ~ 
                              str_replace_all(string=PlotID,pattern="-",replacement="_"),
                            .default=PlotID)) %>% 
  mutate(PlotID = case_when(ProjectName=="Alaska Arctic DO 2019" ~ 
                              str_to_upper(string=PlotID),
                            .default=PlotID)) %>% 
  mutate(PlotID = case_when(ProjectName=="ALASKA_GMT2_2021" ~
                              str_pad(PlotID,3,side="left",pad="0"),
                            .default = PlotID))

# Format GMT-2 and Alaska Arctic DO 2019 sites to match plot name conventions
plot_cover = plot_cover %>% 
  mutate(site_code = case_when(ProjectName=="Alaska Arctic DO 2019" & grepl(pattern="PLOT", x=PlotID) ~ 
                                 str_c("GMT2",
                                       str_pad(str_split_i(string=PlotID,pattern="_",i=2),3,side="left",pad="0"),
                                       sep = "-"),
                               ProjectName == "ALASKA_GMT2_2021" ~ str_c("GMT2",PlotID,sep="-"),
                               .default = PlotID))

# Restrict data to relevant sites ----

# Select projects to keep
plot_cover = plot_cover %>% 
  filter(site_code %in% sites$site_code) %>% 
  left_join(sites,by="site_code")

# What sites are missing from the TerrADat database?
sites %>% 
  filter(!(site_code %in% plot_cover$site_code))

# Obtain site_visit_id ----
# By joining to AKVEG site_visit_table using 'site' as a key
plot_cover = plot_cover %>% 
  left_join(visit_all,by="site_code")

# Did every site code in the plot_cover table find a match in the AKVEG site_visit table?
plot_cover %>% 
  filter(is.na(site_visit_code))

# Format data ----

# Select columns to keep
cols_to_keep = c("site_visit_code",
                 "PointLoc","PointNbr",
                 "HeightHerbaceous","SpeciesHerbaceous",
                 "ChkboxHerbaceous")

# Drop entries for which height is either NA or 0
# Drop data collected on dead vegetation (but keep entries with NA; assume those are alive)
herb_data = plot_cover %>%
  filter(!(is.na(HeightHerbaceous))) %>% 
  filter(HeightHerbaceous != 0) %>% 
  filter(is.na(ChkboxHerbaceous) | ChkboxHerbaceous != 1) %>% 
  select(all_of(cols_to_keep)) %>% 
  arrange(site_visit_code,PointLoc) 

summary(herb_data$ChkboxHerbaceous) # Ensure 1s were dropped but NAs were not
summary(herb_data$HeightHerbaceous) # No zeroes or NAs

# Drop outliers value ----

# Examine maximum values
subset(herb_data,HeightHerbaceous > 80)

# Drop value of 414 cm from the data
herb_data = herb_data %>% 
  filter(HeightHerbaceous != 414)

# Correct taxon names ----
herb_data %>% 
  filter(is.na(SpeciesHerbaceous)) %>% 
  nrow() # 746/7308 = 10% of entries do not have a species associated with them

# Add unknown codes for entries where SpeciesHerbaceous is NA
# Merge with USDA Plants table to obtain species name from species code
herb_data = herb_data %>% 
  left_join(plant_codes,
          by=c("SpeciesHerbaceous"="code_plants")) %>% 
  mutate(name_original = case_when(is.na(SpeciesHerbaceous) ~ "herbaceous",
                                   .default = name_plants))

# Are there any codes that returned a NULL value?
herb_data %>% 
  filter(is.na(name_original)) %>%
  distinct(SpeciesHerbaceous)

# Correct names that do not return any matches after being joined by USDA Plants code
# Refer to the cover_all df for the site_visit_code in question and try to figure out which plant it could be
herb_data = herb_data %>% 
  mutate(name_original = case_when(SpeciesHerbaceous == "POSUB" ~ "Poa sublanata",
                                   SpeciesHerbaceous == "PESU" ~ "Pedicularis sudetica",
                                   SpeciesHerbaceous == "DESUO86" ~ "Deschampsia sukatschewii ssp. orientalis",
                                   SpeciesHerbaceous == "PG01" ~ "PG01",
                                   SpeciesHerbaceous == "PF04" ~ "PF04",
                                   SpeciesHerbaceous == "POBI" ~ "Polygonum bistorta ssp. viviparum",
                                   SpeciesHerbaceous == "ALBO86" ~ "Alopecurus borealis",
                                   SpeciesHerbaceous == "None" ~ "herbaceous",
                                   .default = name_original))

# Check to make sure it worked
herb_data %>% 
  filter(is.na(name_original)) %>% 
  distinct(SpeciesHerbaceous)

# Remove entry for Arctostaphylos alpina
# One entry in which it is listed under SpeciesHerbaceous, which is incorrect (should be listed as shrub)
herb_data = herb_data %>% 
  filter(name_original != "Arctostaphylos alpina" )

# Remove unnecessary columns
herb_data = herb_data %>% 
  select(-c(SpeciesHerbaceous,ChkboxHerbaceous,name_plants))

# Obtain cover data ----
# Restrict cover data to live plants only
cover_all = cover_all %>% 
  filter(dead_status==FALSE) %>% 
  select(site_visit_code,cover_type_id, 
         name_original,code_adjudicated, cover_percent)

# Merge to obtain cover_type & cover_percent
# Will be NA for "herbaceous" codes
herb_data = herb_data %>% 
  left_join(cover_all,by=c("site_visit_code", "name_original"))

# Which entries didn't return a match?
# Most of these are because there isn't an equivalent entry for that site_visit_code in the cover data (not because the species itself doesn't exist)
names_to_fill = herb_data %>% 
  filter(is.na(code_adjudicated)) %>% 
  filter(name_original!="herbaceous") %>% 
  distinct(name_original) %>% 
  print(n=100)

# Create a unique name_original to code_adjudicated table 
# Obtain multiple codes for Polygonum bistorta, Hierochloe pauciflora
# Keep the one associated with the accepted name
cover_codes = cover_all %>%
  mutate(name_original = str_to_sentence(cover_all$name_original)) %>% 
  distinct(name_original, code_adjudicated) %>% 
  filter(name_original %in% names_to_fill$name_original) %>%
  filter(code_adjudicated != "hiepau2" & code_adjudicated != "bisplu") %>% 
  rename(code_to_replace = code_adjudicated)

herb_data = herb_data %>% 
  left_join(cover_codes, by="name_original") %>% 
  mutate(code_adjudicated = case_when(is.na(code_adjudicated)&!is.na(code_to_replace) ~ code_to_replace,
                                      .default = code_adjudicated)) %>% 
  select(-code_to_replace)

# Repeat check
# Remaining ones can be manually corrected
herb_data %>% 
  filter(is.na(code_adjudicated)) %>%
  distinct(name_original)

# Fill in the NA codes with the appropriate taxon codes
herb_data = herb_data %>% 
  mutate(code_adjudicated = case_when(name_original == "PG01" ~ "ugramin",
                                      name_original == "PF04" ~ "uforb",
                                      name_original == "Polygonum bistorta ssp. viviparum" ~ "bisviv",
                                      name_original == "herbaceous" ~ "uherbac",
                                      name_original == "Elymus sibiricus" ~ "elysib",
                                      name_original == "Carex athrostachya" ~ "carathr",
                                      .default = code_adjudicated))

# Check if there are any other NAs to address
herb_data %>% filter(is.na(code_adjudicated))

# Obtain name_adjudicated
# Because 'uherbac' is not yet a known unknown code (!), fill it in manually
herb_data = herb_data %>% 
  left_join(taxa_all,by=c("code_adjudicated"="taxon_code")) %>% 
  mutate(taxon_name = case_when(code_adjudicated == "uherbac" ~ "herbaceous",
                                .default = taxon_name))

herb_data %>% 
  filter(is.na(taxon_name)) %>% 
  distinct(name_original)

# Rename taxon_name column and drop taxon_code column
herb_data = herb_data %>% 
  select(-code_adjudicated) %>% 
  rename(name_adjudicated = taxon_name)

# What entries have a name_original that does not match the name_adjudicated?
herb_data %>% 
  filter(name_original != name_adjudicated) %>% 
  distinct(name_original)

# Summarize heights data ----

# Summarize by species
herb_summary = herb_data %>% 
  group_by(site_visit_code, name_adjudicated) %>% 
  summarise(max_height = max(HeightHerbaceous),
            mean_height = mean(HeightHerbaceous),
            count = n())

# Are there any NULL values?
herb_summary %>% filter(is.na(max_height))
herb_summary %>% filter(is.na(mean_height))

# Convert to long form
herb_summary = herb_summary %>% 
  pivot_longer(cols = c("max_height","mean_height"),
               names_to = "height_type",
               values_to = "height_cm") %>% 
  mutate(height_type = case_when(height_type == "max_height" ~ "point-intercept 98th percentile",
                                 height_type == "mean_height" ~ "point-intercept mean"))

# Summarize by site (total for all herbaceous species)
herb_totals = herb_data %>% 
  group_by(site_visit_code) %>% 
  summarise(max_height = max(HeightHerbaceous),
            mean_height = mean(HeightHerbaceous),
            count = n())

# Convert to long form
herb_totals = herb_totals %>% 
  pivot_longer(cols = c("max_height","mean_height"),
               names_to = "height_type",
               values_to = "height_cm") %>% 
  mutate(height_type = case_when(height_type == "max_height" ~ "point-intercept 98th percentile",
                                 height_type == "mean_height" ~ "point-intercept mean"))


# Populate missing columns ----

# Collapse herb data to unique site visit code / species combination
# To obtain cover percent, cover type, etc.
herb_collapsed = herb_data %>% 
  select(-c("PointLoc","PointNbr","HeightHerbaceous")) %>% 
  group_by(site_visit_code) %>% 
  distinct(name_adjudicated, .keep_all = TRUE)

# Merge with herb_summary data frame
herb_summary = herb_summary %>% 
  left_join(herb_collapsed, by=c("site_visit_code","name_adjudicated"))

# Add totals calculation ----
# Create missing fields
herb_totals = herb_totals %>% 
  mutate(name_adjudicated = "herbaceous (all)",
         name_original = "herbaceous (all)",
         cover_type_id = NA,
         cover_percent = -999)

herb_summary = herb_summary %>% 
  bind_rows(herb_totals) %>% 
  arrange(site_visit_code)

# Complete remaining fields
herb_summary = herb_summary %>% 
  mutate(cover_type = case_when(cover_type_id==1 ~ "absolute foliar cover",
                                is.na(cover_type_id) ~ "NULL"),
         cover_percent = case_when(is.na(cover_percent) ~ -999,
                                   .default = cover_percent),
         herbaceous_subplot_area_m2 = 2827.43,
         height_cm = round(height_cm,digits=2)) %>% 
  select(all_of(template), count) # Keep 'count' column for now

# Remove unknown herbaceous except for in its inclusion in the totals column
herb_summary = herb_summary %>% 
  filter(name_original != "herbaceous") %>% 
  mutate(name_original = case_when(name_original == "herbaceous (all)" ~ "herbaceous",
                                   .default = name_original),
         name_adjudicated = case_when(name_adjudicated == "herbaceous (all)" ~ "herbaceous",
                                      .default = name_adjudicated))

# QA/QC ----

# Do any of the columns have null values that need to be addressed?
# None of the columns should have NAs since NA value is NULL for cover_type and -999 for cover_percent
cbind(
  lapply(
    lapply(herb_summary, is.na)
    , sum)
)

# Ensure categorical/single values make sense
unique(herb_summary$herbaceous_subplot_area_m2) # Should be a single value
unique(herb_summary$height_type)
unique(herb_summary$cover_type) # Should be a single value (or NULL)

# Ensure there is no value for cover_percent that is less than 0 and not the null value (-999)
herb_summary %>% filter(cover_percent < 0) %>% 
  ungroup() %>% 
  distinct(cover_percent)

# Verify range of height values
summary(herb_summary$height_cm)
hist(herb_summary$height_cm)

# Export data ----
write_csv(herb_summary, output_heights)

# Clean workspace
rm(list=ls())
