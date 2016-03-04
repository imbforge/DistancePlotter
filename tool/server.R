# source:      https://github.com/imbforge/DistancePlotter
# description: Generic tool to produce various types of plots from tabular data. 
# description: Mainly tailored to be run on microscopy data and meant to analyse distance data of FISH stained foci in nuclei.
# description: This tool is the Shiny-R server side script that is supposed to work together with the ui.R located in the same folder.
# constrains : Input is tabular (tab delimited) data including headers. First three columns ("Row", "Column", "Timepoint") are used to construct an Experiment-ID
# author: IMB Bioinformatics Core Facility (Oliver Drechsel)

library(shiny)
library(shinyjs)
library(ggplot2)
library(DT)

# enable file uploads up to 30MB
options(shiny.maxRequestSize=30*1024^2) 

# Define server logic required to draw a plot
shinyServer(function(input, output, session) {
  
  # initialize
  plotting_string <- c("test")
  # maintain a list of available options for selecting columns and max/min values
  gating_list <- list()
  
  # Expression that generates a plot. The expression is
  # wrapped in a call to renderPlot to indicate that:
  #
  #  1) It is "reactive" and therefore should re-execute automatically
  #     when inputs change
  #  2) Its output type is a plot
  
  
  # define plotting method as a whole ggplot string as only plotting method, e.g. geom_violin() does not get executed correctly
  # three different ways of limiting the data - this is important for the calculation of density plots
  # coord_cartesian(ylim=c()) ==> just limits the view and lets the data alone
  # ylim() ==> drops data outside the limited area, hence changes the density plot
  # scale_y_continuous(limits=c()) ==> acts the same as ylim(), hence changes the density plot
  plot.method <- reactive({
    switch(input$method,
           "violin" = 'ggplot(data=plot.data, aes_string("experiment", y_axis))  + geom_violin()        + labs(title=main.title, y=y_label) + scale_y_',
           "violin (coloured)" = 'ggplot(data=plot.data, aes_string("experiment", y_axis, fill="experiment"))  + geom_violin()        + labs(title=main.title, y=y_label) + scale_fill_manual(values=present_colours) + scale_y_',
           "boxplot" = 'ggplot(data=plot.data, aes_string("experiment", y_axis)) + geom_boxplot()       + labs(title=main.title, y=y_label) + scale_y_',
           "boxplot (coloured)" = 'ggplot(data=plot.data, aes_string("experiment", y_axis, fill="experiment")) + geom_boxplot()       + labs(title=main.title, y=y_label) + scale_fill_manual(values=present_colours) + scale_y_',
           "jitter" = 'ggplot(data=plot.data, aes_string("experiment", y_axis)) + geom_jitter(size=0.1)       + labs(title=main.title, y=y_label) + scale_y_',
           "jitter (coloured)" = 'ggplot(data=plot.data, aes_string("experiment", y_axis, colour="experiment")) + geom_jitter(size=0.1)       + labs(title=main.title, y=y_label) + scale_colour_manual(values=present_colours) + scale_y_',
           "density" = 'ggplot(data=plot.data, aes_string(y_axis, color="experiment")) + geom_density() + labs(title=main.title, x=y_label) + scale_x_',
           # color="experiment" is important here, because later we'll filter based on the key word "colour" --- if ( all(sapply(present_colours, is.null)) & grepl("colour", p) ) {...}
           "density (fill)" = 'ggplot(data=plot.data, aes_string(y_axis, fill="experiment", color="experiment")) + geom_density(alpha=transparency_value)    + labs(title=main.title, x=y_label) + scale_x_',
           "density (fill, coloured)" = 'ggplot(data=plot.data, aes_string(y_axis, fill="experiment", colour="experiment")) + geom_density(alpha=transparency_value)    + labs(title=main.title, x=y_label) + scale_fill_manual(values=present_colours) + scale_color_manual(values=present_colours) + scale_x_',
           "histogram (stack)" = 'ggplot(data=plot.data, aes_string(y_axis, fill="experiment")) + geom_histogram()                 + labs(title=main.title, x=y_label) + scale_x_',
           "histogram (stack, coloured)" = 'ggplot(data=plot.data, aes_string(y_axis, fill="experiment")) + geom_histogram()                 + labs(title=main.title, x=y_label) + scale_fill_manual(values=present_colours) + scale_x_',
           "histogram (dodge)" = 'ggplot(data=plot.data, aes_string(y_axis, fill="experiment")) + geom_histogram(position="dodge") + labs(title=main.title, x=y_label) + scale_x_',
           "histogram (dodge, coloured)" = 'ggplot(data=plot.data, aes_string(y_axis, fill="experiment")) + geom_histogram(position="dodge") + labs(title=main.title, x=y_label) + scale_fill_manual(values=present_colours) + scale_x_',
           "barplot" = 'ggplot(data=plot.data, aes_string(y_axis, fill="experiment")) + geom_bar(position="dodge")       + labs(title=main.title, x=y_label) + scale_x_',
           "barplot (coloured)" = 'ggplot(data=plot.data, aes_string(y_axis, fill="experiment")) + geom_bar(position="dodge")       + labs(title=main.title, x=y_label) + scale_fill_manual(values=present_colours) + scale_x_'
    )
  })
  
  # load data here
#   raw.data <- reactive({
#       if (is.null(input$file_input)) {return(NULL)}
#       tmp.data <- read.table(file=input$file_input$datapath, header=T, sep='\t', stringsAsFactors=FALSE)
#       # produce a column containing the experiment name 
#       tmp.data$experiment <- paste(tmp.data$Row, tmp.data$Column, tmp.data$Timepoint,sep='_')
#       return(tmp.data)
#   })
  raw.data <- reactive({
      
      if (is.null(input$file_input)) {return(NULL)}
      
      else if (input$file_input$type == 'application/zip') {
      
        # produce a temporary folder for unzipping
        target_dir <- paste0( dirname(input$file_input$datapath), '1')
        fused_file <- paste0( target_dir, '/fused_file.tsv' )
        
        # catch all file names and finally unzip the data
        file_list <- unzip(input$file_input$datapath, list=T, overwrite=F)
        system( paste0("unzip ", input$file_input$datapath, ' -d ', target_dir))
        
        # system call to run python script
        # output needs to be written to temporary directory
        system( paste0("python unite_data_v3.py --data ", target_dir, " --out ", fused_file))
        
        # read python table output to R data table
        # this table already contains an "experiment" column
        tmp.data <- read.table(file=fused_file, header=T, sep='\t', stringsAsFactors=FALSE)
        
        # replace letters or signs that could be understood as mathematical symbols in later eval() commands
        tmp.data$experiment <- gsub("[-*/+]", "_", tmp.data$experiment)
        
        # remove unzipped folder?
        system( paste0('rm -r ', target_dir) )
        
        return(tmp.data)
    }
    else {
      
        tmp.data <- read.table(file=input$file_input$datapath, header=T, sep='\t', stringsAsFactors=FALSE)
        
        # produce a column containing the experiment name 
        if(! 'experiment' %in% colnames(tmp.data)) {
          tmp.data$experiment <- paste(tmp.data$Row, tmp.data$Column, tmp.data$Timepoint,sep='_')
        }
        
        # replace letters or signs that could be understood as mathematical symbols in later eval() commands
        tmp.data$experiment <- gsub("[-*/+]", "_", tmp.data$experiment)
        
        tmp.data$experiment <- as.factor(tmp.data$experiment)
        
        return(tmp.data)
    }
  })
  
  
  # load translation table
  translation.data <- reactive({
    if (is.null(input$file_translation)) {return(NULL)}
    read.table(file=input$file_translation$datapath, header=T, sep='\t', stringsAsFactors=FALSE)
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
    
    order.levels <- c( unique(t.data$temp.experiment), unique(tmp.data$experiment[is.na(tmp.data$temp.experiment)]) ) # use the same order for plotting that is found in the translation table and add all elements not found in that table at the end
    
    tmp.data$temp.experiment[is.na(tmp.data$temp.experiment)] <- tmp.data$experiment[is.na(tmp.data$temp.experiment)] # fix names of temp.experiment names that were generated as NA while merging
    tmp.data$experiment <- factor(tmp.data$temp.experiment, levels=order.levels) # overwrite old experiment IDs
    tmp.data$temp.experiment <- NULL # clean up
    named.data <- tmp.data # re-create plot.data
    rm(tmp.data) # clean more
    return(named.data)
  })
  
  # get data to be plotted (separate from ggplot function)
  plot.raw.data <- reactive ({
    
    tmp.data <- all.data()
    
    # is there data to be plotted?
    if (is.null(tmp.data)) { return(NULL) }
    
    # is there anything selected to be plotted?
    if (is.null(input$column_select)) { return(NULL) }
    
    # !!! not needed any more after splitting data formatting and plotting !!!
    # if no selection criteria are put - report everything
    # plotted data can be limited by selection of one other column -> gating_column
    # unless it is selected that everything should be plotted (which is the default)
    # if (input$selector_moreless == "all" & is.null(input$selector_list)) { return(tmp.data) }
    
    # !!! not needed any more after splitting data formatting and plotting !!!
    # use only those rows where the gating column satisfies the criteria
    # if no value is given, plot whole data set
    # if (is.null(input$value_limit) | is.na(input$value_limit)) { return(tmp.data) }
    
    # !!!                                     !!! #
    # !!! THE FOLLOWING STEPS CHANGE TMP.DATA !!! #
    # !!!                                     !!! #
    
    # create a selection criteria, e.g. all.data[all.data$dontknow>0.2, ]
    if (input$selector_moreless != "all" & !(is.null(input$value_limit) | is.na(input$value_limit))) {
      if(input$selector_moreless == '=') {
        moreless <- '=='
      }
      else {
        moreless <- input$selector_moreless
      }
      # print( paste0("tmp.data$", input$gating_column, moreless, input$value_limit) )
      selector <- paste0("tmp.data$", input$gating_column, moreless, input$value_limit) # TODO: test if excluding NA is important/necessary: " & !is.na(", input$gating_column,")"
      tmp.data <- tmp.data[eval(parse(text=selector)),]
    }
    
    # add further selection criteria from input$selector_list (aka checkboxGroup)
    if ( !is.null(input$selector_list) ) {
      # from "list" to "tmp.data$condition1 & tmp.data$condition2"
      selector_list <- paste("tmp.data$", input$selector_list, sep='', collapse=" & ")
      tmp.data <- tmp.data[eval(parse(text=selector_list)),]
    }
    
    # select samples to plot
    if (!is.null(input$sample_select)) {
      
      tmp.data <- tmp.data[tmp.data$experiment %in% input$sample_select,]
      # a simple select would retain all original levels in factor
      # need to wipe them out 
      tmp.data$experiment <- droplevels(tmp.data$experiment)
    }
    
    return(tmp.data)
    
  })
  
  # produce statistics on input values
  stat.data <- reactive({
    
    if (is.null(all.data())) {return(NULL)}
    
    test.data <- all.data()
    
    # split selected data column by experiment
    # TODO use selected samples only?
    test.data.list <- split(test.data[,input$column_select], test.data$experiment)
    
    # produce matrix sized experiment_number x experiment_number
    matrix_pvalue <- matrix(data=NA, nrow=length(names(test.data.list)), ncol=length(names(test.data.list)))
    rownames(matrix_pvalue) <- names(test.data.list)
    colnames(matrix_pvalue) <- names(test.data.list)
    
    # iterate through all combinations of Mann-Whitney-Wilcox tests
    for (i in names(test.data.list)) {
      for (j in names(test.data.list)) {
        print(c(i,j))
        if ( length(test.data.list[[i]]) == 0 | length(test.data.list[[j]]) == 0 ) {
          test <- data.frame("p.value"=NA)
        }
        else {
          test <- wilcox.test( test.data.list[[i]], test.data.list[[j]] )
        }
        print(test)
        matrix_pvalue[i,j] <- test$p.value
      }
    }
    
    return(matrix_pvalue)
    
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
  
  # select, which samples to plot
  output$sample_names <- renderUI({
      
      named.data  <- all.data()
      experiments <- as.factor(named.data$experiment)
      checkboxGroupInput("sample_select",
                         label="Select samples to plot",
                         choices=levels(experiments),
                         selected=levels(experiments)
        )
  })
  
  # select, which colour the samples should be plotted in (need to first load the experiment names and then generate a list of input colour pickers)
  output$sample_colours <- renderUI({
      if (is.null(all.data())) {return(NULL)}
      
      named.data  <- all.data()
      experiments <- input$sample_select
      
      tagList(
        lapply(experiments,
               function(x) {
                 colourInput( paste0("sample_colour_", x),
                              label=paste0("Choose colour for: ",x),
                              showColour="background",
                              palette="limited"
                   )
               }
               )
        )
    
  })
  
  # limit the plotted borders of data (depending on plot this value (input$upper_limit) is used as ylimit, xlimit)
  output$y_maximum <- renderUI({
      
      if (is.null(input$column_select)) {
        max_value = NULL
      }
      else if (!is.factor(all.data()[,input$column_select])) {
        max_value = max( all.data()[,input$column_select] )
      }
      else {
        max_value = NULL
      }
    
      numericInput("upper_limit", 
                   label = "maximum value", 
                   value = max_value
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
  
  # actively influence maximum or minimum value of gating column - value stored in input$value_limit
  output$selector_value <- renderUI({
    
    if (is.null(input$gating_column)) {
      max_value = NULL
    }
    else if (!is.factor(all.data()[,input$gating_column])) {
      max_value = max( all.data()[,input$gating_column] )
    }
    else {
      max_value = NULL
    }
    
    numericInput("value_limit",
                 label = "Limit of column selected",
                 value = max_value
      )
    
  })
  
  # collect selection criteria and make them available via a check box list
  # updates the checkboxGroup as soon as "add Filter" button is hit
  # currently only runs using a global variable
  observe({
    # if button not hit yet, don't do anything
    if ( is.null(input$addSelector) | input$addSelector == 0 ) { 
      return() 
    }
    else {
      # add the new selector to the old list and produce a new checkboxGroup
      index <- input$addSelector
      value <- isolate( paste(input$gating_column, input$selector_moreless, input$value_limit, collapse=' ') ) # isolate() to not add new selecotrs while selecting options
      value <- gsub("=", "==", value)
      # clean out filters that contain "all", because they are useless (input is a list, hence the sapply)
      value <- value[!sapply(value, function(x) {grepl("all",x)})]
      gating_list[[index]] <<- value
      cb_options <- unlist(gating_list)
      updateCheckboxGroupInput(session, "selector_list", choices=cb_options)
    }
  })
  
  # static UI elements
  
  # debug messages
#   output$text1 <- renderText({ 
#       print(input$sample_select)
#     })
  
  # magic behind the download plot button
  output$downloadPlot <- downloadHandler(
      filename = "plot.pdf",
      content = function(file) {
          # write pdf of ggplot
          ggsave(filename=file, width=200, height=150, unit="mm")
      }
  )
  
  # magic behind the download settings button
  output$downloadSettings <- downloadHandler(
    filename = "plot_settings.txt",
    content = function(txtfile) {
      # write txt file containing the settings
      plot.settings <- data.frame("parameter" = "setting",  stringsAsFactors = FALSE)
      
      plot.settings$input_file       <- input$file_input$name
      plot.settings$translation_file <- input$file_translation$name
      plot.settings$column_select    <- input$column_select
      plot.settings$plot_label <- input$plot_label
      plot.settings$axis_label <- input$y_label
      plot.settings$min_limit  <- input$lower_limit
      plot.settings$max_limit  <- input$upper_limit
      selector <- paste0(input$gating_column, " ", input$selector_moreless, " ", input$value_limit)
      plot.settings$gating     <- selector
      plot.settings$samples    <- paste(input$sample_select, collapse=', ')
      plot.settings$ggplot     <- gsub("\\s+", " ", plotting_string) # remove consecutive white spaces

      write.csv(plot.settings, txtfile, row.names=FALSE)
    }
  )
  
  # download the filtered data shown in the data table beneath the plot
  output$downloadFilteredData <- downloadHandler(
    filename = "filtered_data.tsv",
    content = function(file) {
      write.table(plot.raw.data(), file = file, sep='\t', row.names=FALSE, col.names=TRUE, quote = FALSE)
    }
  )

  # download the raw input data
  output$downloadData <- downloadHandler(
    filename = "raw_data.tsv",
    content = function(file) {
      write.table(raw.data(), file = file, sep='\t', row.names=FALSE, col.names=TRUE, quote = FALSE)
    }
    )

  # magic behind the download table button
  output$downloadTable <- downloadHandler(
    filename = "WilcoxTest.csv",
    content = function(csvfile) {
      # write csv from table
      write.csv(stat.data(), csvfile)
    }
  )
  
  ##################
  #    Plot Area   #
  ##################


  # a glimpse on the data - a plain head worked well
  # output$view <- renderTable({
  #     colnames(all.data())
  #     head(all.data())
  # })
  # but a data table is way more nice
  output$viewData <- DT::renderDataTable(DT::datatable({
    
    # return(all.data())
    return(plot.raw.data())
    
  }))
  
  # the plotting area (which is not a density plot, although the name suggests that)
  output$densPlot <- renderPlot({
    
    # function to create an empty plot with a text complaining about what is not good.
    empty_plot <- function(anders) {
      ggplot(data=data.frame(x=1)) + 
      geom_text(aes_q(10,20, label=anders)) + 
      labs(x="", y="") + 
      scale_x_continuous(breaks = 1, labels = "") + 
      scale_y_continuous(breaks = 1, labels = "")
    }
    
    # get the plotting data (already pre-filtered by input$ parameters)
    plot.data <- plot.raw.data()
    
    if (is.null(plot.data)) { 
      return( empty_plot("not enough data...") )
    }
    
    # produce color vector for plotting
    present_experiments <- unique(plot.data$experiment)
    present_experiments <- present_experiments[!is.na(present_experiments)] # no NA please
    # make sure the experiments read from the data table have the same sorting as in the ggplot area
    if ( is.null(translation.data()) ) {
      # no translation table will yield an alphabetical sort in ggplot output
      present_experiments <- sort(present_experiments) 
    }
    else {
      # existing translation table will influence the sort order in the plot and needs to be applied here as well
      translation.table <- translation.data()
      present_experiments <- present_experiments[order(match(present_experiments, translation.table[,2]))]
    }
    present_colours_variables <- sapply( present_experiments, function(x) {paste0("input$sample_colour_",x)} ) # create input$ variable names created for the selection tab in the UI in "output$sample_colours <-"
    present_colours <- sapply(present_colours_variables, function(x){eval(parse(text=x))}) # read out the input field colours values "eval" must be used, because the variable names generated earlier are treated as text
    names(present_colours) <- NULL # otherwise ggplot-fill will be transparent with no colour (don't know, if this is a bug or feature)
    
    transparency_value <- 1/length( levels(as.factor(present_experiments)) )
    
    # produce some labels
    y_axis <- input$column_select # y_axis is used to define aesthetics
    main.title <- input$plot_label
    y_label <- input$y_label
    
    # return empty plot, if restriction is too harsh
    if (dim(plot.data)[1] <= 1 ) { 
      return( empty_plot("not enough data after filtering") )
    }
    else if (input$lower_limit == 0 & input$axis_scaling == "log10") {
      return( empty_plot("minimal value=0 and log scaling violate laws of math") )
    }
    else if (!is.numeric(plot.data[,input$column_select])) {
      return( empty_plot("trying to plot non-numerical data ... and failed.") )
    }
    # kind of double negation: NA would yield all FALSE, values yield TRUE - if any row contains values - there you are!
    else if (any( !is.na(plot.data[,input$column_select]) )) {
      p <- plot.method() # save the plotting method to a variable
      
      # check if no colours were selected (this happens, if "Samples tab" was not activated until now)
      # it's important to check here for "colour", which ensures that the "density (fill)" graph doesn't get picked up - The plotting line uses color=experiment to avoid getting picked up
      if ( all(sapply(present_colours, is.null)) & grepl("colour", p) ) {
        return( empty_plot("no colours selected that are needed to stain the samples.") )
      }
      
      # check which axis to zoom:
      if (grepl("density", p) | grepl("histogram", p) | grepl("bar", p)) { which_axis = "xlim" } else { which_axis = "ylim" }
      
      # add the scaling method and the limits
      # result: "ggplot(data=plot.data, aes_string(\"experiment\", y_axis))  + geom_violin() + labs(title=main.title, y=y_label) + scale_y_continuous( limits=c(input$lower_limit, input$upper_limit) )"
      p <- paste0( p, input$axis_scaling, "() + coord_cartesian( ", which_axis, "=c(input$lower_limit, input$upper_limit) )" ) 
      
      # check, if it is necesssary to turn the x labels, because otherwise they might overlap
      # in density and histograms this is not necessary as the experiment ID are then located at the y axis
      if ( !(grepl("density", p) | grepl("histogram", p) | grepl("bar", p)) ) {
        if (  nchar(paste0(levels(as.factor(plot.data$experiment)), collapse = '')) > 150  ) {
          p <- paste0( p, ' + theme(axis.text.x = element_text(angle = 45, hjust = 1)) ')
        }
      }
      
      plotting_string <<- p # save the plotting line to a global variable - i know it's a bad idea...
      eval(parse(text=p)) # force to execute the following:
      # ggplot(data=plot.data, aes_string("experiment", y_axis)) + plot.method() + labs(title=main.title, y="count")
      # a direct execution of this line works on command line, but not in shinyApp, hence the eval() expression
      
      
      
    }
    
    # hmm Captain Obvious says that the following should be obvi...
    else {
      return( empty_plot("something went wrong...") )
    }
  }) # end of densPlot()
  
  # print out the statistics in a "n by n" matrix in a nice DataTable format
  output$MannWitneyTest <- DT::renderDataTable(
    DT::datatable({ 
      return(stat.data()) 
    })
  )

}) # end of script
