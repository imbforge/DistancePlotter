# DistancePlotter #

## Running ##

- create a folder to accomodate DistancePlotter, e.g. PlottingApp
- copy server.R and ui.R into that folder, e.g. PlottingApp or `git clone https://github.com/imbforge/DistancePlotter.git`
- the application can be run either via command line R or Rstudio

### command line R ###
    library(shiny)
    runApp(PlottingApp)


### Rstudio ###
- open either server.R, ui.R or both
- hit "Run App"
- depending on your preferences you can maximise the window into browser

## Usage ##

![screenshot_mainwindow](figures/main_window_v2.png "Main Window 1")

### Data ###
The "Data" tab is used to open data files and download plot data
- all input files should be saved as TAB delimited files
- the file containing the data to be plotted should contain headers
- DistancePlotter will create an "experiment ID" from the 3 columns named "Row", "Column", "Timepoint", e.g. "2_4_0"

- a translation table can be used to name experiments according to your wishes
   - the file should be TAB delimited without headers
   - first column should contain the "experiment ID", e.g. 2_4_0
   - second column should contain your desired experiment name
   - the order of experiments given in this file will determine the order of experiments plotted

### Plotting ###
All fields of the "Plot" tab influence the plot shown on the right hand side instantly and can be revised at any time.
- select the type of plot
   - density will draw empty areas
   - density (fill) will draw colored areas
   - histogram (stack) will stack all bars
   - histogram (dodge) will print each experiment's bar starting at x-axis

- select which column to plot
- select samples to plot ("Samples" tab)


- change the title and y-axis label of the plot, whereas y-axis label will be used as x-axis label for density plots and histograms

- limiting of plotted data and scaling of the y- or x-axis may cause confusion, i.e. log10 scaling with minimal value=0

- one column can be selected to filter the plotted data, e.g. to selectively show data of nuclei containing 2 spots, ...

- Download will save the last plot as "plot.pdf"

The "Samples" tab may be used to:
- select samples to plot (each change will reset this tab including color choices)
- select which color the samples are plotted in

### Statistics ###
- ! Note: don't get nervous, if no statistics is shown immediately. It takes a bit... !
- DistancePlotter will calculate Mann-Whitney (aka Wilcoxon) test on all data selected in the column to plot
- a matrix of all vs. all will be shown and can be downloaded as csv (comma separated file)

## ToDo ##
- (done) influence the order of experiments shown
- (done) influence experiment color
- (done) second factor selection should sport "=" as well
- second factor selection may also be written as free text to enter custom combination of factors
- (done) statistics to identify significantly different distributions (Mann-Whitney-U test)


