# -*- coding: utf-8 -*-
# ---------------------------------------------------------------------------
# Data visualization for indicator comparison
# Author: Timm Nawrocki, Alaska Center for Conservation Science
# Last Updated: 2024-01-11
# Usage: Code chunks must be executed sequentially in R Studio or R Studio Server installation.
# Description: "Data visualization for indicator comparison" specifies a shiny app to visualize data across strata.
# ---------------------------------------------------------------------------

# Import libraries
library(DT)
library(shiny)
library(dplyr)
library(leaflet)
library(plotly)
library(stringr)
library(shinythemes)

# Set root directory
drive = '/srv'
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

# Define input pick list
indicator_list = as.list(c('depth_restrictive_layer_cm', 'depth_moss_duff_cm'))

#### CREATE WEB APPLICATION

# Define page layout
ui = fluidPage(theme = shinytheme('lumen'),
               
               # App title
               tags$h1('Indicator comparison among strata', align = 'center'),
               tags$br(),
               
               # Sidebar layout
               sidebarLayout(
                 
                 # Sidebar panel for user inputs and map outputs
                 sidebarPanel(
                   selectInput('indicator',
                               'Choose an indicator',
                               indicator_list)
                 ),
                 
                 # Main panel for displaying outputs
                 mainPanel(
                   plotlyOutput('indicator_plot', height = 450),
                   tags$h2("Summary Table"),
                   dataTableOutput('summary_table'),
                   tags$br(),
                   tags$br()
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
      # Remove problem strata
      filter(strata != 'AB' &
               strata != 'AFAG' &
               strata != 'AFMM' &
               strata != 'TMCD') %>%
      # Rename the selected indicator
      rename(selected = !!indicator) %>%
      # Remove no data
      filter(selected != -999)
    environment_data
  })
  
  # Create output table
  output$summary_table <- renderDataTable({
    summary_table = environment_filtered() %>%
      select(strata, selected) %>%
      group_by(strata) %>%
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
              color = ~strata,
              type = 'box',
              points = "all", 
              jitter = 0.3,
              pointpos = 0,
              marker = list (color = 'black', size = 12), 
              line = list (color = 'black'),
              hoverinfo = 'text',
              text = ~paste('</br> site visit code: ', site_visit_code,
                            '</br> Indicator Value: ', selected)
      ) %>%
      layout( yaxis = list(title = str_replace_all(input$indicator, '_', ' '))) %>%
      layout( yaxis = list(titlefont = list(size = 22), tickfont = list(size = 22))) %>%
      layout( xaxis = list(zerolinecolor = '#ffff',
                           zerolinewidth = 2,
                           gridcolor = 'ffff',
                           showticklabels=TRUE)) %>%
      layout(showlegend = FALSE)
    # Display plot
    print(p)
  })
}

# Create Shiny app ----
shinyApp(ui, server)