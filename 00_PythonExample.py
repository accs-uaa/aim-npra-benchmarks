# -*- coding: utf-8 -*-
# ---------------------------------------------------------------------------
# Code template for Python
# Author: Timm Nawrocki
# Last Updated: 2024-04-05
# Usage: Execute in Python 3.10+.
# Description: "Code template for Python" provides an example structure for a Python executable script.
# ---------------------------------------------------------------------------

# Import packages
import os
import time
import pandas as pd
from akutils import end_timing
from akutils import connect_database_postgresql
from akutils import query_to_dataframe
from warnings import simplefilter
simplefilter(action="ignore", category=pd.errors.PerformanceWarning)

# Set root directory
drive = 'D:/'
root_folder = 'ACCS_Work'

# Define folder structure
credentials_folder = os.path.join(drive, root_folder, 'Administrative/Credentials/akveg_public_read')
repository_folder = os.path.join(drive, root_folder, 'Repositories/aim-npra-benchmarks')
project_folder = os.path.join(drive, root_folder, 'Projects/VegetationEcology/BLM_AIM_NPRA_Benchmarks/Data')
input_folder = os.path.join(project_folder, 'Data_Input', 'strata')
output_folder = os.path.join(project_folder, 'Data_Output', 'strata')

# Define input files
strata_input = os.path.join(input_folder, 'AIM_NPRA_Strata.csv')
functional_input = os.path.join(project_folder, 'Data_Output/functional_groups', 'AIM_NPRA_Functional_Groups.csv')
authentication_file = os.path.join(credentials_folder, 'authentication_akveg_public.csv')
vegetation_query_file = os.path.join(repository_folder, 'queries', 'npra_05_vegetation_query.sql')
groundcover_query_file = os.path.join(repository_folder, 'queries', 'npra_08_ground_query.sql')
environment_query_file = os.path.join(repository_folder, 'queries', 'npra_12_environment_query.sql')

# Define output files
strata_output = os.path.join(output_folder, 'AIM_NPRA_Strata_Revised.csv')

#### QUERY AKVEG DATABASE
####------------------------------

# Create a connection to the AKVEG Database
print('Querying AKVEG Database...')
iteration_start = time.time()
database_connection = connect_database_postgresql(authentication_file)

# Query the vegetation cover data
print('\tQuerying vegetation cover data...')
file_read = open(vegetation_query_file, 'r')
vegetation_query = file_read.read()
file_read.close()
vegetation_data = query_to_dataframe(database_connection, vegetation_query)
vegetation_data.drop(vegetation_data.loc[vegetation_data['dead_status']==True].index, inplace=True)

# Pivot the vegetation cover data from long to wide
vegetation_wide = vegetation_data.pivot_table(index=['site_visit_code'], columns='code_accepted',
                    values=['cover_percent'], aggfunc='first')
vegetation_wide.columns = [f'{column_name[1]}' for column_name in vegetation_wide.columns]
vegetation_wide = vegetation_wide.reset_index()

# Query the ground cover data
print('\tQuerying ground cover data...')
file_read = open(groundcover_query_file, 'r')
groundcover_query = file_read.read()
file_read.close()
groundcover_data = query_to_dataframe(database_connection, groundcover_query)

# Pivot the ground cover data from long to wide
groundcover_wide = groundcover_data.pivot_table(index=['site_visit_code'], columns='ground_element',
                                                values=['ground_cover_percent'], aggfunc='first')
groundcover_wide.columns = [f'{column_name[1]}' for column_name in groundcover_wide.columns]
groundcover_wide = groundcover_wide.reset_index()

# Query the environment data
print('\tQuerying environment data...')
file_read = open(environment_query_file, 'r')
environment_query = file_read.read()
file_read.close()
environment_data = query_to_dataframe(database_connection, environment_query)

# Join the environment data to the vegetation data
character_data = vegetation_wide.merge(environment_data, how = 'inner',
                                       left_on = 'site_visit_code', right_on = 'site_visit_code')
character_data = character_data.merge(groundcover_wide, how = 'inner',
                                       left_on = 'site_visit_code', right_on = 'site_visit_code')

# Close database connection
database_connection.close()
end_timing(iteration_start)

#### CALCULATE INDICATOR CHARACTERS
####------------------------------

# Read csv files
print('Calculating indicators...')
iteration_start = time.time()
strata_data = pd.read_csv(strata_input)
functional_data = pd.read_csv(functional_input)

# Join original strata
character_data = character_data.merge(strata_data, how = 'inner',
                                      left_on = 'site_visit_code', right_on = 'site_visit_code')

# Add a wetland sedge character
print('\tCalculating wetland sedge cover...')
wetsed_data = vegetation_data.merge(functional_data, how = 'inner',
                                    left_on = 'code_accepted', right_on = 'taxon_accepted_code')
wetsed_data.drop(wetsed_data.loc[wetsed_data['wetland_sedge']!='wetland sedge'].index, inplace=True)
wetsed_sum = wetsed_data.groupby(['site_visit_code'])['cover_percent'].sum().reset_index()
wetsed_sum = wetsed_sum.rename(columns={'cover_percent': 'wetsed'})
character_data = character_data.merge(wetsed_sum, how = 'left',
                                      left_on = 'site_visit_code', right_on = 'site_visit_code')

# Add an aquatic moss character
print('\tCalculating aquatic moss cover...')
aqumos_data = vegetation_data.merge(functional_data, how = 'inner',
                                    left_on = 'code_accepted', right_on = 'taxon_accepted_code')
aqumos_data.drop(aqumos_data.loc[aqumos_data['nv_functional_gr']!='aquatic moss'].index, inplace=True)
aqumos_sum = aqumos_data.groupby(['site_visit_code'])['cover_percent'].sum().reset_index()
aqumos_sum = aqumos_sum.rename(columns={'cover_percent': 'aqumos'})
character_data = character_data.merge(aqumos_sum, how = 'left',
                                      left_on = 'site_visit_code', right_on = 'site_visit_code')

# Fill na with -999
character_data = character_data.fillna(-999)
end_timing(iteration_start)

#### PROGRAMMATIC KEY TO STRATA
####------------------------------

# Initialize revised columns
print('Running programmatic key to strata...')
iteration_start = time.time()
character_data['physiography_revised'] = 'none'

# Separate wetland types
print('\tSeparating wetland physiography...')
character_data.loc[
    (character_data['physiography_revised'] == 'none') &
    ((character_data['wetsed'] > 20) | (character_data['aqumos'] > 10) | (character_data['water'] > 20)),
    'physiography_revised'] = 'wetland'

# Separate tussock tundra types
print('\tSeparating tundra physiography...')
character_data.loc[
    (character_data['physiography_revised'] == 'none') &
    (character_data['erivag'] > 10),
    'physiography_revised'] = 'tundra'

# Select columns and export data
print('\tExporting final data...')
export_columns = ['site_code', 'site_visit_code', 'physiography_revised']
output_data = character_data[export_columns]
output_data.to_csv(strata_output, header=True, index=False, sep=',', encoding='utf-8')
end_timing(iteration_start)
