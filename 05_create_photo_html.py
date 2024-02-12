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
photo_input = os.path.join(data_folder, 'AIM_NPRA_Photo_List.csv')

# Read input data
photo_data = pd.read_csv(photo_input)
site_list = photo_data['folder_name'].unique()

# Loop through all sites and create html output
for image_folder in site_list:
    # Define output files
    output_html = os.path.join(data_folder, 'html', f'{image_folder}.html')

    # Delete html file if it already exists
    if os.path.exists(output_html) == 1:
        os.remove(output_html)

    # Open new html file in write mode
    f = open(output_html, 'w')

    # Create the html code
    html_string = f'''<!DOCTYPE html>
    <html> 
    <head>
    <link rel="stylesheet" href="https://fonts.googleapis.com/css?family=Roboto">
    <title>Site Visit Photos for {image_folder}</title> 
    </head> 
    <body>
    <h1 style="text-align:center;font-family:'Roboto',sans-serif;font-weight:lighter;">Site Visit Photos for {image_folder}</h1>
    <div id="container" style="display:flex;flex-direction:row;flex-wrap:wrap;justify-content:center;width:90%;margin:auto;">'''

    # Add each photo thumbnail to html
    photo_list = photo_data['image_name'].loc[photo_data['folder_name'] == image_folder].unique()
    for photo_file in photo_list:
        html_addition = f'''\t<a href="{url_root + image_folder + '/' + photo_file}", style="display:inline-block;margin:10px;";><img src="{url_root + image_folder + '/' + photo_file}" style="width:300px;height:225px;object-fit:cover;object-position:25%25%;"></a>\n'''
        html_string = html_string + html_addition

    html_string = html_string + '''\n</div>
    </body> 
    </html>'''

    # writing the code into the file
    f.write(html_string)

    # close the file
    f.close()
