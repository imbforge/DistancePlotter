library(shiny)
library(ggplot2)
# library(reshape2)
# library(plyr)

# Define UI for application that draws a histogram
shinyUI(fluidPage(

  # Application title
  titlePanel("Data Plotter"),

  # Sidebar with a slider input for the number of bins
  sidebarLayout(
    sidebarPanel(
        # get the data file
        fileInput('file_input', 'Choose Input File',
                  accept=c('text/txt', 'text/tsv')
                  ),
        # experiment IDs (from column 1-3) are transformed to meaningful names given in this file
        fileInput('file_translation', 'Choose Translation File'                  
                  ),
      
        selectInput("method", label = "Choose a plot:", 
                  choices = c("violin", "boxplot", "density", "density (fill)", "histogram (stack)", "histogram (dodge)"),
                  selected = "violin"
                  ),
      
        # numericInput("column", "Number of column to plot:", 22),
        
        uiOutput("column_names"), # which column to plot
        
        uiOutput("sample_names"), # which samples to plot
        
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
                     choices = list("all" = "all", "<" = "<", ">" = ">"),
                     selected = "all"
        ),
        uiOutput("selector_value"),


#         h5("get your plot"),
        downloadButton('downloadPlot', 'Download')
        
    ),

    # Show a plot of the generated distribution
    mainPanel(
      # show a density plot (influenced by "method"'s data set and measurement count)
      plotOutput("densPlot"),
      # show a head of the new data set (influenced by "method")
      tableOutput("view")#,
      
      # just report some debug messages
      #textOutput("text1")
    )
  )
))
