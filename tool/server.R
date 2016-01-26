library(shiny)
library(ggplot2)


# Define server logic required to draw a plot
shinyServer(function(input, output) {

  # Expression that generates a plot. The expression is
  # wrapped in a call to renderPlot to indicate that:
  #
  #  1) It is "reactive" and therefore should re-execute automatically
  #     when inputs change
  #  2) Its output type is a plot
  
  
  # define plotting method as a whole ggplot string as only plotting method, e.g. geom_violin() does not get executed correctly
  plot.method <- reactive({
    switch(input$method,
           "violin" = 'ggplot(data=plot.data, aes_string("experiment", y_axis))  + geom_violin()        + labs(title=main.title, y=y_label) + scale_y_',
           "boxplot" = 'ggplot(data=plot.data, aes_string("experiment", y_axis)) + geom_boxplot()       + labs(title=main.title, y=y_label) + scale_y_',
           "density" = 'ggplot(data=plot.data, aes_string(y_axis, color="experiment")) + geom_density() + labs(title=main.title, x=y_label) + scale_x_',
           "density (fill)" = 'ggplot(data=plot.data, aes_string(y_axis, fill="experiment", color="experiment")) + geom_density()    + labs(title=main.title, x=y_label) + scale_x_',
           "histogram (stack)" = 'ggplot(data=plot.data, aes_string(y_axis, fill="experiment")) + geom_histogram()                 + labs(title=main.title, x=y_label) + scale_x_',
           "histogram (dodge)" = 'ggplot(data=plot.data, aes_string(y_axis, fill="experiment")) + geom_histogram(position="dodge") + labs(title=main.title, x=y_label) + scale_x_'
    )
  })
  
  # load data here
  raw.data <- reactive({
      if (is.null(input$file_input)) {return(NULL)}
      tmp.data <- read.table(file=input$file_input$datapath, header=T, sep='\t', stringsAsFactors=FALSE)
      # produce a column containing the experiment name 
      tmp.data$experiment <- paste(tmp.data$Row, tmp.data$Column, tmp.data$Timepoint,sep='_')
      return(tmp.data)
  })
  
  # load translation table
  translation.data <- reactive({
    if (is.null(input$file_translation)) {return(NULL)}
    read.table(file=input$file_translation$datapath, header=F, sep='\t', stringsAsFactors=FALSE)
  })
  
  # name experiments in data table
  all.data <- reactive({
    # check the prerequisites
    if (is.null(input$file_input)) { return(NULL) }
    if (is.null(input$file_translation)) { return(raw.data()) }
    
    # name the experiments
    t.data <- translation.data()
    colnames(t.data) <- c("experiment","temp.experiment")
    
    # fuse the two tables, move added column to old "experiment" column and delete the added temp column
    noname.data <- raw.data()
    tmp.data <- merge( noname.data, t.data, by="experiment", all.x=TRUE )
    tmp.data$temp.experiment[is.na(tmp.data$temp.experiment)] <- tmp.data$experiment[is.na(tmp.data$temp.experiment)] # fix names of temp.experiment names that were generated as NA while merging
    tmp.data$experiment <- tmp.data$temp.experiment # overwrite old experiment IDs
    tmp.data$temp.experiment <- NULL # clean up
    named.data <- tmp.data # re-create plot.data
    rm(tmp.data) # clean more
    return(named.data)
  })
  

  ##################
  # User Interface #
  ##################
  
  # the following renderUI is used to dynamically generate the tabsets when the file is loaded. Until the file is loaded, app will not show the tabset.
  # this is copied from http://stackoverflow.com/questions/28162306/cannot-populate-drop-down-menu-dynamically-in-r-shiny
  # select, which column to plot (by name)
  output$column_names <- renderUI({
      
      selectInput("column_select", 
                  label="Select a column to plot",  
                  choices=names(all.data()),
                  selected=names(all.data())[length(all.data())]
                  )
  })
  
  output$sample_names <- renderUI({
      
      named.data  <- all.data()
      experiments <- as.factor(named.data$experiment)
      checkboxGroupInput("sample_select",
                         label="Select samples to plot",
                         choices=levels(experiments),
                         selected=levels(experiments)
        )
  })
  
  # limit the plotted borders of data (depending on plot this value (input$upper_limit) is used as ylimit, xlimit)
  output$y_maximum <- renderUI({
      
      numericInput("upper_limit", 
                   label = "maximum value", 
                   #value = "100"
                   value = max( all.data()[,input$column_select] )
      ) # the maximum value of y axis
  })
  
  # actively influence the plot title - value stored in input$plot_label
  output$plot_title <- renderUI({
    textInput("plot_label", label = "Choose main title of plot", value = input$column_select)
  })
  
  # actively influence, which column to limit the data that are plotted - value goes to input$gating_column
  output$selector_column <- renderUI({
    
    selectInput("gating_column",
                label="Select a column to limit data",
                choices=names(all.data()),
                selected=NULL
                )
  })
  
  # actively influence maximum or minimum value - value stored in input$value_limit
  output$selector_value <- renderUI({
    
    numericInput("value_limit",
                 label = "Limit of column selected",
                 value = max( all.data()[,input$gating_column] )
      )
    
  })
  
  # static UI elements
  
  # debug messages
  output$text1 <- renderText({ 
      print(input$sample_select)
    })
  
  # magic behind the download button
  output$downloadPlot <- downloadHandler(
      filename = "plot.pdf",
      content = function(file) {
          # write pdf of ggplot
          ggsave(filename=file, width=200, height=150, unit="mm")
      }
  )
  
  # a glimpse on the data
  output$view <- renderTable({
      colnames(all.data())
      head(all.data())
  })
  
  # the plotting area (which is not a density plot, although the name suggests that)
  output$densPlot <- renderPlot({
    
    print(input$sample_select)
    
    # function to create an empty plot
    empty_plot <- function(anders) {
      ggplot(data=data.frame(x=1)) + 
      geom_text(aes_q(10,20, label=anders)) + 
      labs(x="", y="") + 
      scale_x_continuous(breaks = 1, labels = "") + 
      scale_y_continuous(breaks = 1, labels = "")
    }
    
    # draw a plot according to the data put in and the selected plotting method
    # an empty frame is plotted, if no data are supplied
    if (is.null(all.data())) {
        # plot an empty area complaining about too little data
        empty_plot("not enough data")
    }
    else {
        
        # plotted data can be limited by selection of one other column -> gating_column
        # unless it is selected that everything should be plotted (which is the default)
        if (input$selector_moreless == "all") {
          plot.data <- all.data()
        }
        else {
          # use only those rows where the gating column satisfies the criteria
          if (is.null(input$value_limit) | is.na(input$value_limit)) { # if no value is given, plot whole data set
            plot.data <- all.data()
          }
          else {
            # create a selection criteria, e.g. all.data[all.data$dontknow>0.2, ]
            selector <- paste0("tmp.data$", input$gating_column, input$selector_moreless, input$value_limit) # TODO: test if excluding NA is important/necessary: " & !is.na(", input$gating_column,")"
            tmp.data <- all.data()
            plot.data <- tmp.data[eval(parse(text=selector)),]
            rm(tmp.data) # clean up a little
          }
        }
        
        # clean out data a bit
        #plot.data <- plot.data[plot.data$experiment != "NA_NA_NA", ]
        
        # select samples to plot
        if (!is.null(input$sample_select)) {
          plot.data <- plot.data[plot.data$experiment == input$sample_select,]
        }
        
        # produce some labels
        y_axis <- input$column_select # y_axis is used to define aesthetics
        main.title <- input$plot_label
        y_label <- input$y_label
        
        # return empty plot, if restriction is too harsh
        if (dim(plot.data)[1] <= 1 ) { 
          empty_plot("not enough data after filtering") 
        }
        else if (input$lower_limit == 0 & input$axis_scaling == "log10") {
          empty_plot("minimal value=0 and log scaling violate laws of math")
        }
        else if (!is.numeric(plot.data[,input$column_select])) {
          empty_plot("trying to plot non-numerical data ... and failed.")
        }
        # kind of double negation: NA would yield all FALSE, values yield TRUE - if any row contains values - there you are!
        else if (any( !is.na(plot.data[,input$column_select]) )) {
          p <- plot.method() # save the plotting method to a variable
          # add the scaling method and the limits
          # result: "ggplot(data=plot.data, aes_string(\"experiment\", y_axis))  + geom_violin() + labs(title=main.title, y=y_label) + scale_y_continuous( limits=c(input$lower_limit, input$upper_limit) )"
          p <- paste0( p, input$axis_scaling, "( limits=c(input$lower_limit, input$upper_limit) )" ) 
          eval(parse(text=p)) # force to execute the following:
          # ggplot(data=plot.data, aes_string("experiment", y_axis)) + plot.method() + labs(title=main.title, y="count")
          # a direct execution of this line works on command line, but not in shinyApp, hence the eval() expression
        }
        # 
        else {
          empty_plot("something went wrong...")
        }
    }
  })
})
