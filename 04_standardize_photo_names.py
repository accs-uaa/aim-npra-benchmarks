# -*- coding: utf-8 -*-
# ---------------------------------------------------------------------------
# Standardize photo names
# Author: Amanda Droghini
# Last Updated: 2024-02-12
# Usage: Execute in Python 3.9+.
# Description: "Standardize photo names" iterates through JPG files in the NPR-A photo folders and standardizes file names. Examples of changes include: including appropriate site code, removing date strings, truncating photo descriptions to a single letter (e.g., s for soil shots).
# ---------------------------------------------------------------------------

# Import libraries
import re
from pathlib import Path

# Set directory
project_dir = Path('C:/ACCS_Work/Projects/BLM_NPRA_AIM_Benchmarks/npra_photos')

# Correct prefix for GMT-2 sites
for input_file in project_dir.rglob("*.jpg"):
    file_name = input_file.name

    if file_name.startswith("NPRA_PLOT"):
        replace_name = file_name.replace('NPRA_PLOT', 'GMT2_')
        input_file.rename(input_file.parent / replace_name)

    elif file_name.startswith('NPRA_Plot'):
        replace_name = file_name.replace('NPRA_Plot', 'GMT2_')
        input_file.rename(input_file.parent / replace_name)

# Remove prefix for other (non GMT-2) sites
for input_file in project_dir.rglob("*.jpg"):
    file_name = input_file.name

    if file_name.startswith('NPRA2015_'):
        replace_name = file_name.replace('NPRA2015_', '')
        input_file.rename(input_file.parent / replace_name)

    elif file_name.startswith('NPRA_'):
        replace_name = file_name.replace('NPRA_', '')
        input_file.rename(input_file.parent / replace_name)

# Remove date string
for input_file in project_dir.rglob("*.jpg"):
    file_name = input_file.name

    if re.search(r'(_+\d{8}+$)', input_file.stem):
        replace_name = re.sub(r'(_+\d{8})','',string=file_name)
        input_file.rename(input_file.parent / replace_name)

# Standardize photo descriptors to single letter code
for input_file in project_dir.rglob("*.jpg"):
    file_name = input_file.name

    if re.search(pattern="(?i)soilcontext", string=file_name):
        replace_name = re.sub(r'(?i)' + 'soilcontext', 's', string=file_name)
        input_file.rename(input_file.parent / replace_name)

    if re.search(pattern="(?i)aerial", string=file_name):
        replace_name = re.sub(r'(?i)'+'aerial','a',string=file_name)
        input_file.rename(input_file.parent / replace_name)

    if re.search(pattern="(?i)people", string=file_name):
        replace_name = re.sub(r'(?i)' + 'people', 'm', string=file_name)
        input_file.rename(input_file.parent / replace_name)

    if re.search(pattern="(?i)veg", string=file_name):
        replace_name = re.sub(r'(?i)' + 'veg', 'v', string=file_name)
        input_file.rename(input_file.parent / replace_name)

    if re.search(pattern="(?i)overview", string=file_name):
        replace_name = re.sub(r'(?i)' + 'overview', 'a', string=file_name)
        if Path.exists((input_file.parent / replace_name)):
            print(replace_name + " already exists")
        else:
            input_file.rename(input_file.parent / replace_name)

    if re.search(pattern="(?i)general", string=file_name):
        replace_name = re.sub(r'(?i)' + 'general', 'm', string=file_name)
        if Path.exists((input_file.parent / replace_name)):
            print(replace_name + " already exists")
        else:
            input_file.rename(input_file.parent / replace_name)

# More standardizing to single letter code
for input_file in project_dir.rglob("*.jpg"):
    file_name = input_file.name

    if re.search(pattern="(?i)aer", string=file_name):
        replace_name = re.sub(r'(?i)'+'aer','a',string=file_name)
        input_file.rename(input_file.parent / replace_name)

    if re.search(pattern="(?i)air", string=file_name):
        replace_name = re.sub(r'(?i)'+'air','a',string=file_name)
        input_file.rename(input_file.parent / replace_name)

    if re.search(pattern="(?i)misc", string=file_name):
        replace_name = re.sub(r'(?i)'+'misc','m',string=file_name)
        if Path.exists((input_file.parent / replace_name)):
            print(replace_name + " already exists")
        else:
            input_file.rename(input_file.parent / replace_name)

    if re.search(pattern="(?i)soil", string=file_name):
        replace_name = re.sub(r'(?i)' + 'soil', 's', string=file_name)
        input_file.rename(input_file.parent / replace_name)

# Replace 'landscape' descriptor with 'm' (for misc)
for input_file in project_dir.rglob("*.jpg"):
    file_name = input_file.name

    if re.search(pattern="(?i)landscape", string=file_name):
        replace_name = re.sub(r'(?i)'+'landscape','m',string=file_name)
        if Path.exists((input_file.parent / replace_name)):
            print(replace_name + " already exists")
        else:
            input_file.rename(input_file.parent / replace_name)

# Replace 'other' descriptor with 'm' (for misc)
for input_file in project_dir.rglob("*.jpg"):
    file_name = input_file.name

    if re.search(pattern="(?i)other", string=file_name):
        replace_name = re.sub(r'(?i)'+'other','m',string=file_name)
        if Path.exists((input_file.parent / replace_name)):
            print(replace_name + " already exists")
        else:
            input_file.rename(input_file.parent / replace_name)

# Remove trailing space and parentheses
for input_file in project_dir.rglob("*.jpg"):
    file_name = input_file.name

    if re.search(pattern="[\s+(+)]", string=file_name):
        replace_name = re.sub(r'[\s+(+)]','',string=file_name)
        input_file.rename(input_file.parent / replace_name)

# Remove dates in the middle of file names
for input_file in project_dir.rglob("*.jpg"):
    file_name = input_file.name

    if re.search(pattern="(_+\d{6}+_)", string=file_name):
        replace_name = re.sub(r'(_+\d{6}+_)','_',string=file_name)
        input_file.rename(input_file.parent / replace_name)

# Convert photo descriptor codes to lower case
for input_file in project_dir.rglob("*.jpg"):
    file_name = input_file.name

    if re.search(pattern="(_\w+\d)", string=file_name):
        replace_name = re.sub(pattern=r'(_\w+\d)', repl=lambda m: m.group(0).lower(),string=file_name)
        input_file.rename(input_file.parent / replace_name)