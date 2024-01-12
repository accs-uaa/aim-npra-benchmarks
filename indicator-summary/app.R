# -*- coding: utf-8 -*-
# ---------------------------------------------------------------------------
# Data visualization for indicator summary per stratum
# Author: Timm Nawrocki, Alaska Center for Conservation Science
# Last Updated: 2024-01-11
# Usage: Code chunks must be executed sequentially in R Studio or R Studio Server installation.
# Description: "Data visualization for indicator summary per stratum" specifies a shiny app to visualize data for one stratum and one indicator. Based on code originally developed by Allyson Richins, BLM (contractor).
# ---------------------------------------------------------------------------

# Import libraries
library(DT)
library(shiny)
library(dplyr)
library(leaflet)
library(plotly)
library(stringr)

# Set root directory
drive = 'srv'
root_folder = 'shiny-server'

# Define input folders
app_folder = paste(drive,
                   root_folder,
                   'indicator-summary',
                   sep = '/')

# Define input files
environment_file = paste(app_folder,
                         'data',
                         '12_environment_aimnpra2017.csv',
                         sep = '/')
site_visit_file = paste(app_folder,
                        'data',
                        '03_sitevisit_aimnpra2017.csv',
                        sep = '/')
site_file = paste(app_folder,
                  'data',
                  '02_site_aimnpra2017.csv',
                  sep = '/')

# Read input files to data frames
environment_data = readr::read_csv(environment_file) %>%
  # Create a strata field from the site visit code
  mutate(strata = str_replace(site_visit_code, "-.*", ""))
site_visit_data = readr::read_csv(site_visit_file)
site_data = readr::read_csv(site_file) %>%
  mutate(strata = str_replace(site_code, "-.*", ""))

# Define input pick list
strata_list = as.list(unique(environment_data['strata']))
indicator_list = as.list(c('depth_restrictive_layer_cm', 'depth_moss_duff_cm'))

#### CREATE WEB APPLICATION

# Define page layout
ui = fluidPage(
  
  # App title
  titlePanel("Summary statistics per stratum"),
  
  # Sidebar layout
  sidebarLayout(
    
    # Sidebar panel for user inputs and map outputs
    sidebarPanel(
      selectInput('stratum',
                  'Select stratum',
                  strata_list),
      selectInput('indicator',
                  'Choose an indicator',
                  indicator_list),
      leafletOutput('site_map')
      ),
    
    # Main panel for displaying outputs
    mainPanel(
      plotlyOutput('indicator_plot'),
      textOutput('summary_title'),
      dataTableOutput('summary_table'),
      textOutput('outlier_title'),
      verbatimTextOutput('outlier_table')
    )
  )
)

# Create server function to process inputs and outputs
server = function(input, output) {
  
  # Render data tables
  environment_filtered = reactive({
    indicator = input$indicator
    environment_data = readr::read_csv(environment_file) %>%
      # Create a strata field from the site visit code
      mutate(strata = str_replace(site_visit_code, "-.*", "")) %>%
      # Filter by input stratum
      filter(strata == input$stratum) %>%
      # Rename the selected indicator
      rename(selected = !!indicator) %>%
      # Remove no data
      filter(selected != -999)
    environment_data
  })
  
  # Create output map
  output$site_map <- renderLeaflet({
    site_filtered = site_data %>%
      filter(strata == input$stratum)
    m <- leaflet(site_filtered) %>%
      addTiles() %>%
      addWMSTiles(
        "https://geoportal.alaska.gov/arcgis/services/ahri_2020_rgb_cache/MapServer/WMSServer",
        layers = 1,
        options = WMSTileOptions(format = "image/png", transparent = FALSE)) %>%
      addCircleMarkers(lng = ~longitude_dd, lat = ~latitude_dd, radius = 1, popup = ~site_code)
    m})
  
  # Create output text and tables
  output$summary_title <- renderText('Summary Statistics')
  output$summary_table <- renderDataTable({
    summary_table = environment_filtered() %>%
      select(selected) %>%
      summarize(minimum = round(min(selected), 1),
                `lower 2.5%` = round(quantile(selected, 0.025), 1),
                median = round(median(selected), 1),
                mean = round(mean(selected), 1),
                `upper 97.5%` = round(quantile(selected, 0.975), 1),
                maximum = round(max(selected), 1))
    datatable(summary_table, options = list(dom = 't'), rownames=FALSE)
  })

  # Create output plot
  output$indicator_plot <- renderPlotly({
    p = environment_filtered() %>%
      plot_ly(y = ~selected,
              type = 'violin',
              box = list(
                visible = T
                ),
              points = "all", 
              jitter = 0.3,
              pointpos = 0,
              marker = list (color = 'black', size = 12), 
              line = list (color = 'black'),
              hoverinfo = 'text',
              text = ~paste('</br> site visit code: ', site_visit_code,
                            '</br> Indicator Value: ', selected)
              ) %>%
      layout( yaxis = list(title = input$indicator)) %>%
      layout( yaxis = list(titlefont = list(size = 22), tickfont = list(size = 22))) %>%
      layout( xaxis = list(zerolinecolor = '#ffff',
                           zerolinewidth = 2,
                           gridcolor = 'ffff',
                           showticklabels=FALSE))
    # Display plot
    print(p)
  })
}

# Create Shiny app ----
shinyApp(ui, server) 
