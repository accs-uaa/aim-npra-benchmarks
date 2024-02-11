# -*- coding: utf-8 -*-
# ---------------------------------------------------------------------------
# Create site photo html pages
# Author: Timm Nawrocki
# Last Updated: 2024-02-11
# Usage: Execute in Python 3.9+.
# Description: "Create site photo html pages" creates standardized pages for viewing site photos for each site.
# ---------------------------------------------------------------------------

# Import packages
import os
import pandas as pd

# Define url root
url_root = 'https://storage.googleapis.com/accs-public-data/npra_photos/'

# Define base folder structure
drive = 'D:/'
root_folder = 'ACCS_Work'

# Define data folder
data_folder = os.path.join(drive, root_folder,
                           'Projects/VegetationEcology/BLM_AIM_NPRA_Benchmarks/Data/Data_Output')

# Define input file
strata_input = os.path.join(data_folder, 'strata/AIM_NPRA_Strata.csv')

# Read input data
strata_data = pd.read_csv(strata_input)
visit_list = strata_data['site_code'].unique()

# Loop through all sites and create html output
for visit_code in visit_list:
    # Define output files
    output_html = os.path.join(data_folder, 'html', f'{visit_code}.html')

    # Delete html file if it already exists
    if os.path.exists(output_html) == 1:
        os.remove(output_html)

    # Open new html file in write mode
    f = open(output_html, 'w')

    # Create the html code
    html_string = f'''<html> 
    <head> 
    <title>Site Visit Photos for {visit_code}</title> 
    </head> 
    <body>
    <h1 style="text-align:center;">Site Visit Photos for {visit_code}</h1>
    <br>'''

    # List all photos in directory
    photo_list = ['AB1B_t2a.jpg', 'AB1B_t2b.jpg']

    # Add each photo thumbnail to html
    for photo_file in photo_list:
        html_addition = f'''<a href="{url_root + visit_code + '/' + photo_file}", style="margin:10px";><img src="{url_root + visit_code + '/' + photo_file}" style="width:200px;"></a>'''
        html_string = html_string + html_addition

    html_string = html_string + '''\n</body> 
    </html>'''

    # writing the code into the file
    f.write(html_string)

    # close the file
    f.close()
