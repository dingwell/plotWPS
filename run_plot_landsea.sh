#!/bin/bash
# Tool to create plot using "plot_landsea.ncl" from the command-line
#
# Installation:
# 1. Put this script in your system path or in the desired working directory
# 2. Modify the PATH_TO_PLOT_LANDSEA variable to point to the location of
#    the plot_landsea.ncl
# 
# Usage examples:
#   run_plot_landsea.sh file1 file2 [file3 [...]]
#
#   run_plot_landsea.sh subfolder/geo_em*.nc

PATH_TO_PLOT_LANDSEA=$HOME/programming/git/plotWPS/

export FILES=$@

#ncl "$PATH_TO_PLOT_LANDSEA/plot_landsea.ncl" |tail -n +6
echo " NCAR Command Language Version $(ncl -V)"
ncl "$PATH_TO_PLOT_LANDSEA/plot_landsea.ncl"|sed -e '1,5d'


