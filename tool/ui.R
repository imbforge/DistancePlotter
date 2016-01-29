library(shiny)
library(shinyjs)
library(ggplot2)
library(DT)
# library(reshape2)
# library(plyr)

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
                                                     "density", 
                                                     "density (fill)", 
                                                     "density (fill, coloured)", 
                                                     "histogram (stack)", 
                                                     "histogram (stack, coloured)", 
                                                     "histogram (dodge)",
                                                     "histogram (dodge, coloured)"
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
                             uiOutput("selector_value")
                             
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
      tabsetPanel( type="tabs",
                   tabPanel ("Plot & Table",
                              # show a density plot (influenced by "method"'s data set and measurement count)
                              plotOutput("densPlot"),
                              # download the plot
                              downloadButton('downloadPlot', 'Download Plot'),
                              # show a head of the new data set (influenced by "method")
                              #tableOutput("view")
                              DT::dataTableOutput("viewData")
                              
#                    )
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
