# source:      https://github.com/imbforge/DistancePlotter
# description: Generic tool to produce various types of plots from tabular data. 
# description: Mainly tailored to be run on microscopy data and meant to analyse distance data of FISH stained foci in nuclei.
# description: This tool is the Shiny-R user interface that is supposed to work together with the server.R located in the same folder.
# constrains : Input is tabular (tab delimited) data including headers. First three columns ("Row", "Column", "Timepoint") are used to construct an Experiment-ID
# author: IMB Bioinformatics Core Facility (Oliver Drechsel)

library(shiny)
library(shinyjs)
library(ggplot2)
library(DT)


# Define UI for application that draws a histogram
shinyUI(fluidPage(

  # Application title
  titlePanel("Distance Plotter"),

  # Sidebar with a slider input for the number of bins
  sidebarLayout(
    sidebarPanel(
      tabsetPanel( type="tabs",
      #===========================================================================================================
                   tabPanel ("Data",
                      # get the data file
                      fileInput('file_input', 'Choose Input File',
                                accept=c('text/txt', 'text/tsv')
                                ),
                      # experiment IDs (from column 1-3) are transformed to meaningful names given in this file
                      fileInput('file_translation', 'Choose Translation File'                  
                                )
                   ),
      #===========================================================================================================
                   tabPanel ("Plot",
                             selectInput("method", label = "Choose a plot", 
                                         choices = c("violin", 
                                                     "violin (coloured)", 
                                                     "boxplot", 
                                                     "boxplot (coloured)", 
                                                     "jitter", 
                                                     "jitter (coloured)", 
                                                     "density", 
                                                     "density (fill)", 
                                                     "density (fill, coloured)", 
                                                     "histogram (stack)", 
                                                     "histogram (stack, coloured)", 
                                                     "histogram (dodge)",
                                                     "histogram (dodge, coloured)",
                                                     "barplot",
                                                     "barplot (coloured)"
                                                     ),
                                         selected = "violin"
                             ),
                             
                             uiOutput("column_names"), # which column to plot
                             
                             uiOutput("plot_title"), # manually select a plot title
                             
                             textInput("y_label", label = "Choose a y axis label", value = "count"), # influence the label of the y axis
                             numericInput("lower_limit", label = "minimum value", value = "0"), # the minimum value of y axis
                             
                             
                             uiOutput("y_maximum"),
                             
                             radioButtons("axis_scaling", 
                                          label = "y scaling", 
                                          choices = list("linear" = "continuous", "log10" = "log10"),
                                          selected = "continuous"),
                             
                             uiOutput("selector_column"),
                             radioButtons("selector_moreless",
                                          label = "Less or more",
                                          choices = list("all" = "all", "<" = "<", ">" = ">", "=" = "="),
                                          selected = "all"
                             ),
                             uiOutput("selector_value"),
                             
                             actionButton('addSelector', 'Add Filter'),
                             
                             checkboxGroupInput("selector_list",
                                                label = "Select selection criteria",
                                                choices = c()
                                                )
                             
                   ),
      #===========================================================================================================
                   tabPanel ("Samples",
                             
                             uiOutput("sample_names"), # which samples to plot
                             
                             uiOutput("sample_colours")
                   )
      )  
    ),

    # Show a plot of the generated distribution
    mainPanel(
      img(src='IMB_logo_small.png', align = "right"),
      tabsetPanel( type="tabs",
                   tabPanel ("Usage",
                             includeMarkdown("README_viewInPlotter.md")),
                   tabPanel ("Plot & Table",
                              
                             fluidRow(
                             
                              column(12,
                                     # show a density plot (influenced by "method"'s data set and measurement count)
                                     plotOutput("densPlot"),
                                
                                     # produce a row of download button
                                     fluidRow(
                                       column(2,
                                              # download the plot
                                              downloadButton('downloadPlot', 'Download Plot')
                                              ),
                                              # download plot settings & input variables
                                       column(2,
                                              downloadButton('downloadSettings', 'Download Settings')
                                              ),
                                              # download the input data or unzipped/shaped data 
                                       column(2,
                                              downloadButton('downloadData', 'Download Raw Data')
                                              ),
                                              # download filtered table
                                       column(2,
                                              downloadButton('downloadFilteredData', 'Download Filtered Data')
                                              ),
                                       
                                       # show a head of the new data set (influenced by "method")
                                       #tableOutput("view")
                                       DT::dataTableOutput("viewData")
                                     )
                              )
                             )
                   ),
                   tabPanel ("Statistics",
                             # produce a table containing the p values of the respectively tested column
                             DT::dataTableOutput("MannWitneyTest"),
                             
                             # downlowad the stuff
                             downloadButton('downloadTable', 'Download Table')
                   )
      ) # end of tabsetPanel
      
      # just report some debug messages
      #textOutput("text1")
    )
  )
))
