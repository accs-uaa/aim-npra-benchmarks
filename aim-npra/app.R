# -*- coding: utf-8 -*-
# ---------------------------------------------------------------------------
# Data visualization for NPR-A AIM indicators
# Author: Timm Nawrocki, Amanda Droghini, Alaska Center for Conservation Science
# Last Updated: 2024-02-11
# Usage: Code chunks must be executed sequentially in R Studio or R Studio Server installation.
# Description: "Data visualization for indicator comparison" specifies a shiny app to visualize indicator and strata relationships.
# ---------------------------------------------------------------------------

# Import libraries
library(DT)
library(dplyr)
library(leaflet)
library(plotly)
library(purrr)
library(readr)
library(stringr)
library(shiny)
library(shinyjs)
library(shinythemes)
library(shinyWidgets)
library(tibble)
library(tidyr)

# Set root directory
drive = 'D:'
root_folder = 'ACCS_Work/Projects/VegetationEcology/BLM_AIM_NPRA_Benchmarks'

# Define input folders
app_folder = paste(drive,
                   root_folder,
                   'aim-npra',
                   sep = '/')

# Define input files
list_input = paste(app_folder, 'www', 'AIM_NPRA_Indicator_List.csv', sep = '/')
summary_input = paste(app_folder, 'www', 'AIM_NPRA_Indicator_Value.csv', sep = '/')

# Read input data
list_data = read_csv(list_input) %>%
  arrange(type_order, indicator_order)
summary_data = read_csv(summary_input) %>%
  filter(plot_category != 'drop') %>%
  arrange(site_code, indicator) %>%
  # Rescale summary data
  mutate(value = case_when(indicator == 'organic_mineral_ratio_30_cm' ~ round(value * 100, 0),
                           indicator == 'shrub_herbac_height_ratio' ~ round(value * 100, 0),
                           indicator == 'depth_moss_duff_cm' ~ value * 10,
                           indicator == 'soil_pH' ~ value * 10,
                           TRUE ~ value)) %>%
  mutate(indicator = case_when(indicator == 'depth_moss_duff_cm' ~ 'depth_moss_duff_mm',
                               TRUE ~ indicator))
comparison_types = as.list(c('among groups', 'among indicators', 'single indicator/group'))
height_types = as.list(c('mean', 'max'))

# Add directory of static resources to Shiny's web server
#addResourcePath(prefix = 'image_source', directoryPath = paste(app_folder, 'data', sep = '/'))

# Write introduction text
instructions_p1 = 'The sidebar menu provides a set of controls to guide the data exploration. On mobile devices, the sidebar menu will appear at the top of the page, rather than on the side of the page. To get started, select the type of data visualization that you would like to explore. You can select multiple options.'
introduction_p1 = 'In 2011, a pilot project was initiated to adapt AIM to an arctic environment. As part of this pilot, 12 strata were conceptualized, mapped, and sampled following AIM protocols. The strata were defined to capture the variation in biophysical characteristics and site potential across the Arctic Coastal Plain and Brooks Range Foothills. Between 2012 and 2022, 261 plots were sampled within these strata.'
introduction_p2 = 'For each strata, we identified indicator species and indicators of change that can be used to monitor environmental change relative to a reference condition. The following web application is designed to help land managers and BLM staff visually explore these indicators.'
credits = 'Application Design: T.W. Nawrocki, A. Droghini, and L.A. Flagstad; Alaska Center for Conservation Science, University of Alaska Anchorage'

#### DEFINE UI PROCESSING
####------------------------------

ui = fluidPage(theme = shinytheme('lumen'),
               useShinyjs(),
               
               # Link css
               tags$head(
                 tags$link(rel = "stylesheet", type = "text/css", href = "aim-npra.css")
               ),
               
               # App title
               tags$div(id = 'header',
                tags$a(href="https://accs.uaa.alaska.edu",
                        tags$img(src='alaska-center-conservation-science.png', id='logo')),
                tags$h1('Indicator Explorer for AIM NPR-A'),
                tags$br()
               ),
               
               # Sidebar layout
               sidebarLayout(
                 
                 # Sidebar panel for user inputs and map outputs
                 sidebarPanel(
                   checkboxGroupInput('output_toggle', 'Output Toggle', choices = c('plot', 'map', 'data', 'summary'),
                                      selected = NULL, inline = TRUE),
                   checkboxInput('legend', 'Show stratum legend', value = TRUE),
                   checkboxInput('homogeneous', 'Restrict to Homogeneous Only', value = FALSE),
                   radioButtons('grouping', 'Grouping Variable', choices = c('stratum', 'physiography')),
                   selectInput('comparison_type', 'Comparison Type', choices = comparison_types),
                   uiOutput('stratum'),
                   uiOutput('physiography'),
                   selectInput('indicator_type', 'Indicator Type', choices = unique(list_data$type)),
                   uiOutput('indicator'),
                   uiOutput('height_type'),
                   uiOutput('vascular'),
                   uiOutput('species'),
                   tags$br()
                 ),
                 
                 # Main panel for displaying outputs
                 mainPanel(
                   tags$img(src='explorer_banner.jpg', id = 'banner'),
                   tags$div(id='introduction',
                            tags$h2('Instructions'),
                            tags$p(instructions_p1),
                            tags$h2('About the Project'),
                            tags$p(introduction_p1),
                            tags$p(introduction_p2),
                            tags$b(credits),
                            tags$br(),
                            tags$br(),
                            tags$br()
                   ),
                   tags$div(id='plot_section',
                            tags$h2('Indicator Value Plot'),
                            plotlyOutput('indicator_plot', height = 450),
                            tags$br(),
                            tags$br(),
                            tags$br()
                   ),
                   tags$div(id='map_section',
                            tags$h2('Selected Sites'),
                            leafletOutput('site_map'),
                            tags$br(),
                            tags$br(),
                            tags$br()
                   ),
                   tags$div(id='data_section',
                            tags$h2('Indicator Value Table'),
                            dataTableOutput('data_table'),
                            tags$br(),
                            tags$br(),
                            tags$br()
                   ),
                   tags$div(id='summary_section',
                            tags$h2('Summary Table'),
                            dataTableOutput('summary_table'),
                            tags$br(),
                            tags$br(),
                            tags$br()
                   ),
                   tags$div(id='legend_section',
                            tags$h2('Stratum Abbreviations'),
                            dataTableOutput('stratum_legend'),
                            tags$br(),
                            tags$br(),
                            tags$br()
                   ),
                   tags$br()
                 )
               )
)

#### DEFINE SERVER PROCESSING
####------------------------------

server = function(input, output, session) {
  
  #### Process static elements
  ####------------------------------
  
  # Process static data
  species_list = list_data %>%
    filter(type == 'species cover') %>%
    distinct(short_display)
  species_list = list_c(as.vector(species_list))
  vascular_list = list_data %>%
    filter(type == 'vascular cover') %>%
    distinct(short_display)
  vascular_list = list_c(as.vector(vascular_list))
  strata_legend = summary_data %>%
    distinct(stratum_code, stratum_name, physiography)
  strata_data = summary_data %>%
    distinct(stratum_code, stratum_name)
  
  #### CREATE REACTIVE UI
  ####------------------------------
  
  # Create dynamic indicator list
  indicator_list = reactive({
    filter(list_data, type == input$indicator_type)
  })
  
  # Render dynamic UI
  output$indicator = renderUI({
    if (input$comparison_type != 'among indicators') {
      indicator_choices = distinct(indicator_list(), display)
      selectInput('indicator', 'Indicator', choices = indicator_choices)
    }
  })
  output$stratum = renderUI({
    if (input$comparison_type != 'among groups' & input$grouping == 'stratum') {
      stratum_choices = as.list(distinct(summary_data, stratum_name))
      selectInput('stratum', 'Stratum', choices = stratum_choices)
    }
  })
  output$physiography = renderUI({
    if (input$comparison_type != 'among groups' & input$grouping == 'physiography') {
      physiography_choices = as.list(distinct(summary_data, physiography))
      selectInput('physiography', 'Physiography', choices = physiography_choices)
    }
  })
  output$height_type = renderUI({
    if (input$comparison_type == 'among indicators' & input$indicator_type == 'shrub-herbaceous') {
      selectInput('height_type', 'Height Type', choices = height_types)
    }
  })
  output$vascular = renderUI({
    if (input$comparison_type == 'among indicators' & input$indicator_type == 'vascular cover') {
      pickerInput('vascular', 'Select groups (max 6)', choices = vascular_list,
                  multiple = TRUE, options =  list("max-options" = 6)) 
    }
  })
  output$species = renderUI({
    if (input$comparison_type == 'among indicators' & input$indicator_type == 'species cover') {
      pickerInput('species', 'Select species (max 6)', choices = species_list,
                  multiple = TRUE, options =  list("max-options" = 6)) 
    }
  })
  
  #### PROCESS DATA
  ####------------------------------
  
  # Create reactive indicator filter
  indicator_filter = reactive ({
    # Select indicators
    if (input$comparison_type == 'among indicators') {
      indicator_filter = list_data %>%
        filter(type == input$indicator_type) %>%
        distinct(indicator)
      indicator_filter = list_c(as.vector(indicator_filter))
    } else {
      req(input$indicator)
      indicator_filter = list_data %>%
        filter(display == input$indicator) %>%
        distinct(indicator)
      indicator_filter = list_c(as.vector(indicator_filter))
    }
    # Select height type
    if (input$indicator_type == 'shrub-herbaceous') {
      req(input$height_type)
      if(input$height_type == 'max') {
        height_remove = c('shrub_mean_height_cm', 'herbaceous_mean_height_cm')
      } else {
        height_remove = c('shrub_max_height_cm', 'herbaceous_max_height_cm')
      }
      indicator_filter = indicator_filter[!indicator_filter %in% height_remove]
    }
    # Overwrite indicator filter for species cover for the among indicators comparison
    if (input$comparison_type == 'among indicators' & input$indicator_type == 'species cover') {
      req(input$species)
      indicator_filter = list_data %>%
        filter(short_display %in% input$species) %>%
        distinct(indicator)
      indicator_filter = list_c(as.vector(indicator_filter))
    }
    # Overwrite indicator filter for vascular cover for the among indicators comparison
    if (input$comparison_type == 'among indicators' & input$indicator_type == 'vascular cover') {
      req(input$vascular)
      indicator_filter = list_data %>%
        filter(short_display %in% input$vascular) %>%
        distinct(indicator)
      indicator_filter = list_c(as.vector(indicator_filter))
    }
    # Return indicator filter
    indicator_filter
  })
  
  # Create reactive group filter
  group_filter = reactive({
    if (input$comparison_type == 'among groups') {
      if (input$grouping == 'stratum') {
        group_filter = summary_data %>%
          distinct(stratum_code)
        group_filter = list_c(as.vector(group_filter))
      } else {
        group_filter = summary_data %>%
          distinct(physiography)
        group_filter = list_c(as.vector(group_filter))
      }
    } else {
      if (input$grouping == 'stratum') {
        req(input$stratum)
        group_filter = summary_data %>%
          filter(stratum_name == input$stratum) %>%
          distinct(stratum_code)
        group_filter = list_c(as.vector(group_filter))
      } else {
        req(input$physiography)
        group_filter = summary_data %>%
          filter(physiography == input$physiography) %>%
          distinct(physiography)
        group_filter = list_c(as.vector(group_filter))
      }
    }
    # Return group filter
    group_filter
  })
  
  # Create reactive dataframe
  summary_reactive = reactive({
    req(input$grouping)
    # Select columns
    summary_reactive = summary_data %>%
      filter(indicator %in% indicator_filter()) %>%
      filter(if (input$grouping == 'stratum') stratum_code %in% group_filter()
             else physiography %in% group_filter()) %>%
      filter(if (input$homogeneous == TRUE) plot_category == 'homogeneous'
             else plot_category %in% c('homogeneous', 'heterogeneous')) %>%
      drop_na() %>%
      left_join(list_data, by = 'indicator')
    if (input$grouping == 'stratum') {
      summary_reactive = summary_reactive %>%
        mutate(groups = stratum_code)
    } else {
      summary_reactive = summary_reactive %>%
        mutate(groups = physiography)
    }
    # Return dataframe
    summary_reactive
  })
  
  # Create reactive output data
  output_reactive = reactive({
    output_reactive = summary_reactive() %>%
      left_join(list_data, by = 'indicator') %>%
      select(site_code, groups, display, value) %>%
      rename(indicator = display)
    if (input$grouping == 'stratum') {
      output_reactive = output_reactive %>%
        left_join(strata_data, by = c('groups' = 'stratum_code')) %>%
        select(site_code, stratum_name, indicator, value)
    } else {
      output_reactive = output_reactive %>%
        rename(physiography = groups)
    }
    # Return dataframe
    output_reactive
  })
  
  #### CREATE PLOTS
  ####------------------------------
  
  # Create reactive output plot for group comparison
  plot_reactive = reactive({
    if (input$comparison_type == 'among groups') {
      plot_reactive = summary_reactive() %>%
        plot_ly(y = ~value,
                color = ~groups,
                colors = 'BrBG',
                type = 'box',
                points = "all", 
                jitter = 0.3,
                pointpos = 0,
                marker = list (color = 'black', size = 12), 
                line = list (color = 'black'),
                hoverinfo = 'text',
                text = ~paste('</br> site code: ', site_code,
                              '</br> Indicator Value: ', value)
        ) %>%
        layout( yaxis = list(title = str_replace_all(input$indicator, '_', ' '))) %>%
        layout( yaxis = list(titlefont = list(size = 22), tickfont = list(size = 22))) %>%
        layout( xaxis = list(zerolinecolor = '#ffff',
                             zerolinewidth = 2,
                             gridcolor = 'ffff',
                             showticklabels=TRUE)) %>%
        layout(showlegend = FALSE)
    } else if (input$comparison_type == 'among indicators') {
      plot_reactive = summary_reactive() %>%
        plot_ly(y = ~value,
                color = ~short_display,
                colors = 'BrBG',
                type = 'box',
                points = "all", 
                jitter = 0.3,
                pointpos = 0,
                marker = list (color = 'black', size = 12), 
                line = list (color = 'black'),
                hoverinfo = 'text',
                text = ~paste('</br> site code: ', site_code,
                              '</br> Indicator Value: ', value)
        ) %>%
        layout( yaxis = list(titlefont = list(size = 22), tickfont = list(size = 22))) %>%
        layout( xaxis = list(zerolinecolor = '#ffff',
                             zerolinewidth = 2,
                             gridcolor = 'ffff',
                             showticklabels=TRUE)) %>%
        layout(showlegend = FALSE)
    } else {
      plot_reactive = summary_reactive() %>%
        plot_ly(y = ~value,
                type = 'violin',
                colors = 'BrBG',
                box = list(
                  visible = T
                ),
                points = "all", 
                jitter = 0.3,
                pointpos = 0,
                marker = list (color = 'black', size = 12), 
                line = list (color = 'black'),
                hoverinfo = 'text',
                text = ~paste('</br> site code: ', site_code,
                              '</br> Indicator Value: ', value)
        ) %>%
        layout( yaxis = list(title = str_replace_all(input$indicator, '_', ' '))) %>%
        layout( yaxis = list(titlefont = list(size = 22), tickfont = list(size = 22))) %>%
        layout( xaxis = list(zerolinecolor = '#ffff',
                             zerolinewidth = 2,
                             gridcolor = 'ffff',
                             showticklabels=FALSE))
    }
  })
  
  #### RENDER OUTPUTS
  ####------------------------------
  
  # Render legend
  output$stratum_legend = renderDataTable({
    datatable(strata_legend, options = list(dom = 't', pageLength = 1000), rownames=FALSE)
  })
  
  # Render plot
  output$indicator_plot = renderPlotly({
    print(plot_reactive())
  })
  
  # Render data
  output$data_table = renderDataTable({
    datatable(output_reactive(), options = list(pageLength = 8), rownames=FALSE)
  })
  
  # Render summary
  output$summary_table = renderDataTable({
    if (input$grouping == 'stratum') {
      output_summary = output_reactive() %>%
        select(stratum_name, indicator, value) %>%
        group_by(stratum_name, indicator) %>%
        summarize(minimum = round(min(value), 1),
                  `lower 25%` = round(quantile(value, 0.25), 1),
                  median = round(median(value), 1),
                  mean = round(mean(value), 1),
                  `upper 75%` = round(quantile(value, 0.75), 1),
                  maximum = round(max(value), 1))
    } else {
      output_summary = output_reactive() %>%
        select(physiography, indicator, value) %>%
        group_by(physiography, indicator) %>%
        summarize(minimum = round(min(value), 1),
                  `lower 25%` = round(quantile(value, 0.25), 1),
                  median = round(median(value), 1),
                  mean = round(mean(value), 1),
                  `upper 75%` = round(quantile(value, 0.75), 1),
                  maximum = round(max(value), 1))
    }
    datatable(output_summary, options = list(dom = 't', pageLength = 1000), rownames=FALSE)
  })
  
  # Render map
  output$site_map = renderLeaflet({
    site_filtered = summary_reactive() %>%
      distinct(site_code, latitude_dd, longitude_dd)
    m = leaflet(site_filtered) %>%
      addTiles() %>%
      addWMSTiles(
        "https://geoportal.alaska.gov/arcgis/services/ahri_2020_rgb_cache/MapServer/WMSServer",
        layers = 1,
        options = WMSTileOptions(format = "image/png", transparent = FALSE)) %>%
      addCircleMarkers(lng = ~longitude_dd, lat = ~latitude_dd, radius = 1, popup = ~site_code, color = 'red')
    m})
  
  observe({
    toggle(id='plot_section', condition = 'plot' %in% input$output_toggle)
    toggle(id='indicator_plot', condition = 'plot' %in% input$output_toggle)
    toggle(id='map_section', condition = 'map' %in% input$output_toggle)
    toggle(id='site_map', condition = 'map' %in% input$output_toggle)
    toggle(id='data_section', condition = 'data' %in% input$output_toggle)
    toggle(id='data_table', condition = 'data' %in% input$output_toggle)
    toggle(id='summary_section', condition = 'summary' %in% input$output_toggle)
    toggle(id='summary_table', condition = 'summary' %in% input$output_toggle)
    toggle(id='banner', condition = is.null(input$output_toggle))
    toggle(id='introduction', condition = is.null(input$output_toggle))
    toggle(id='legend_section', condition = input$legend == TRUE)
    toggle(id='stratum_legend', condition = input$legend == TRUE)
  })
}

# Create Shiny app ----
shinyApp(ui, server)