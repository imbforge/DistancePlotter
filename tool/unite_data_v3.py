################
# get image analysis data from ..., merge all data, ship out unique IDs for all elements and report a table that is easy to read in R
# this version is intended to run on a whole folder structure
#
# author: Oliver Drechsel
# call: python scripts/unite_data_v2.py --data example_data/MLLAF90to5days-eto1h/0days10uMeto1hKG1__2016-01-09T15_55_35-Measurement1/Evaluation1 --out test.txt
################

import argparse
import sys
import os
import glob
import pprint
import collections
import re
import copy

parser = argparse.ArgumentParser(description='condense features related to the same gene to one start and end position.')

parser.add_argument("--data", dest='in_folder', type=str, required=True, help="The data folder that contains the image analysis output.")
parser.add_argument("--out",  dest='out_file',  type=argparse.FileType('w'), required=True, help="The data output file.")

# initialise and read parameters
args = parser.parse_args()
pp = pprint.PrettyPrinter(indent=5)
DEBUG = pp.pprint

selected_data = collections.OrderedDict()
auxilary_data = dict()
template = collections.OrderedDict()

# initialize translation
translator = dict()
translator['G'] = 'green'
translator['R'] = 'red'
translator['FR'] = 'FarRed'



# check, if the input path exists and contains data files
if not os.path.isdir(args.in_folder):
    exit( "data folder:{0} is not a valid path".format(args.in_folder) )

# earlier version of file opening, if only one input folder is used
# try:
#     temp_in_files = [ '/'.join([args.in_folder,f]) for f in os.listdir(args.in_folder) if os.path.isfile('/'.join([args.in_folder,f])) and f.startswith('Objects') ]
# except:
#     exit("Data folder contained no files")

# in_files = [ open(f) for f in temp_in_files ]

# read folder content, which could be either files only or a complete folder structure with sub experiments
in_folder_struc = glob.glob('/'.join( [args.in_folder, '*'] ))
temp_infiles = list()
sub_in_files = list()
is_files = False

for element in in_folder_struc:
    
    # if only files are encountered
    if os.path.isfile(element) and os.path.basename(element).startswith('Objects'):
        sub_in_files.append(element)
        is_files = True
    
    # if whole folders are encountered
    if os.path.isdir( element ):
        is_files = False
        for dirpath, dirnames, files in os.walk( element ):
            
            sub_in_files = list()
            
            for file_name in files:
                if file_name.startswith('Objects'):
                    sub_in_files.append( os.path.join(dirpath, file_name) )
            
            temp_infiles.append(sub_in_files)

else:
    if is_files is True:
        temp_infiles.append(sub_in_files) # for single folders

# clean out empty elements that originate from subfolders
infiles = [sublist for sublist in temp_infiles if len(sublist) > 0]

for file_name_set in infiles:
    
    in_files = [ open(f) for f in file_name_set ]


    ##################
    # nuclei selected
    ##################
    
    # selected nuclei file in input list
    selected_index = int()
    for element in file_name_set:
        if "Selected" in element:
            selected_index = file_name_set.index(element)
    
    skiplines = True
    write_header = True
    
    for line in in_files[selected_index]:
        line = line.strip()
        
        # experiment ID:
        if line.startswith('Plate Name'):
            experimentID = line.split('\t')[-1]
        
        # skip the header for now
        if line.startswith('[Data]'):
            skiplines = False
            continue
        if skiplines is True:
            continue
        
        splitline = line.split('\t')
        
        # save header
        if line.startswith('Row'):
            header = splitline
            if write_header is True:
                # include "Nuclei Selected - " to all header fields
                # could this be written as a list expression?
                out_header = list()
                out_header.append('experiment')
                for i in range(len(header)):
                    if 'Nuclei Selected' in header[i]:
                        out_header.append( header[i] )
                    else:
                        header_element = 'Nuclei Selected - %s' % header[i]
                        out_header.append( header_element )
                auxilary_data['nucleus'] = '\t'.join( out_header )
                write_header = False
            
            continue
        
        ID_s='_'.join(splitline[0:5]) # selected nuclei ID
        
        selected_data[ID_s] = template.copy()
        selected_data[ID_s]['nucleus'] = template.copy()
        
        for i in range(len(header)):
            if 'Nuclei Selected' in header[i]:
                selected_data[ID_s]['nucleus'][header[i]] = splitline[i]
            else:
                header_element = 'Nuclei Selected - %s' % header[i]
                selected_data[ID_s]['nucleus'][header_element] = splitline[i]
        
        selected_data[ID_s]['experimentID'] = experimentID
        
    ##############    
    # color spots
    ##############
    # this table uses selected nuclei number as indicator
    index = int()
    # find e.g. green in 'Objects_Population - green spots.txt'
    pattern = re.compile(' - (\w+) spots')
    # find e.g. GFR and 1 in 'green spots - GFR_Spot1Index'
    dist_pattern = re.compile(' - (\w+)_Spot(\d+)Index')
    write_header = True
    
    for element in file_name_set:
        if " spots" in element: # the space is important here!
            
            file_index = file_name_set.index(element)
            
            # tell me your color
            match = pattern.search(element)
            
            try:
                color = match.group(1)
            
            except AttributeError:
                continue # to next file
            
            # start reading a spot file
            skiplines = True
    
            for line in in_files[file_index]:
                line = line.strip()
                
                # skip the header for now, but if there is no header just the header row - then start going through the lines
                if line.startswith('[Data]'):
                    skiplines = False
                    continue
                if skiplines is True:
                    continue
                
                
                splitline = line.split('\t')
                
                # save header
                if line.startswith('Row'):
                    header = splitline
                    if write_header is True:
                        # include "Spots - " to all header fields
                        # could this be written as a list expression?
                        out_header = list()
                        for i in range(len(header)):
                            if '_' in header[i]:
                                header_element = header[i].split('_')[1]
                                header_element = 'Spotzz - %s' % header_element
                                out_header.append( header_element )
                            elif 'spots' in header[i]:
                                header_element = header[i].split(' - ')[1]
                                header_element = 'Spotzz - %s' % header_element
                                out_header.append( header_element )
                            else:
                                header_element = 'Spotzz - %s' % header[i]
                                out_header.append(header_element )
                        out_header.append('Spotzz - color')
                        auxilary_data['spot'] = out_header
                        write_header = False
                    continue
                
                # subselect copied from "http://stackoverflow.com/questions/6632188/explicitly-select-items-from-a-python-list-or-tuple"
                ID_s    = '_'.join([splitline[i] for i in [0,1,2,3,20]])
                ID_spot = '_'.join([splitline[i] for i in [0,1,2,3,20,4]])
                ID_spot = '_'.join(['spot', ID_spot, color])
                # ID, which is found in the distance feature file
                ID_dist = list()
                
                # initialise spot
                try:
                    selected_data[ID_s][ID_spot]
                except KeyError:
                    selected_data[ID_s][ID_spot] = template.copy()
                
                # read all spot data
                for i in range(len(header)):
                    if '%s spots' % color in header[i]:
                        selected_data[ID_s][ID_spot][header[i]] = splitline[i]
                    else:
                        header_element = '%s spots - %s' % (color, header[i])
                        selected_data[ID_s][ID_spot][header_element] = splitline[i]
                    
                    # identify elements, e.g. 'green spots - GR_Spot1Index' and NOT 'green spots - Spot Contrast'
                    if '_Spot' in header[i]:
                        dist_match = dist_pattern.search(header[i])
                        dist_color = dist_match.group(1)
                        dist_count = int( dist_match.group(2) )
                        ID_dist.append( '_'.join(['spot%d' % dist_count, ID_s, splitline[i], dist_color]) )
                
                selected_data[ID_s][ID_spot]['color']   = color
                selected_data[ID_s][ID_spot]['ID_dist'] = ID_dist
                
    
    #################
    # spot distances
    #################
    # this table uses selected nuclei as indicator
    index = int()
    pattern = re.compile('(\w+)Spot Pairs')
    
    write_header = True
    
    for element in file_name_set:
        
        if "Pairs" in element: # the space is important here! 
            file_index = file_name_set.index(element)
            
            # tell me your color
            match = pattern.search(element)
            try:
                # expected yield GR, GFR or RFR or ...
                color = match.group(1)
            
            except AttributeError:
                continue # to next file
            
            # identify colors from abbreviation
            if len(color) == 2:
                color1 = translator[color[0]]
                color2 = translator[color[1]]
            # this needs to get more variable and find the correct separation on its own RFR > R|FR or RF|R
            elif len(color) > 2:
                color1 = translator[color[0]]
                color2 = translator[color[1:3]]        
            
            # start reading a spot file
            skiplines = True
    
            for line in in_files[file_index]:
                line = line.strip()
            
            # skip the header for now, but if there is no header just the header row - then start going through the lines
                if line.startswith('[Data]'):
                    skiplines = False
                    continue
                if skiplines is True:
                    continue
                
                
                splitline = line.split('\t')
                
                # save header
                if line.startswith('Row'):
                    header = splitline
                    if write_header is True:
                        # include "Distance - " to all header fields
                        # could this be written as a list expression?
                        out_header = list()
                        for i in range(len(header)):
                            if '_' in header[i]:
                                header_element = header[i].split('_')[1]
                                header_element = 'Distance - %s' % header_element
                                out_header.append( header_element )
                            elif ' - ' in header[i]:
                                header_element = header[i].split(' - ')[1]
                                header_element = 'Distance - %s' % header_element
                                out_header.append( header_element )
                            else:
                                header_element = 'Distance - %s' % header[i]
                                out_header.append(header_element )
                        auxilary_data['distance'] = '\t'.join( out_header )
                        write_header = False
                        
                    continue
                
                
                ID_s    = '_'.join([splitline[i] for i in [0,1,2,3,14]])
                ID_dist = '_'.join([splitline[i] for i in [0,1,2,3,14,13]])
                ID_dist = '_'.join(['dist', ID_dist, color])
                ID_spot_1 = '_'.join([splitline[i] for i in [0,1,2,3,14,15]])
                ID_spot_1 = '_'.join(['spot1', ID_spot_1, color])
                # ID_spot_1 = '_'.join(['spot', ID_spot_1, color1])
                ID_spot_2 = '_'.join([splitline[i] for i in [0,1,2,3,14,16]])
                ID_spot_2 = '_'.join(['spot2', ID_spot_2, color])
                # ID_spot_2 = '_'.join(['spot', ID_spot_2, color2])
                
                selected_data[ID_s][ID_dist] = template.copy()
                
                # read all distance data
                for i in range(len(header)):
                    if 'Spot Pairs' in header[i]:
                        selected_data[ID_s][ID_dist][header[i]] = splitline[i]
                    else:
                        header_element = '%s Spot Pairs - %s' % (color, header[i])
                        selected_data[ID_s][ID_dist][header_element] = splitline[i]
                
                # this is the ID, which could be found in the single spot ID list
                selected_data[ID_s][ID_dist]['spot1'] = ID_spot_1
                selected_data[ID_s][ID_dist]['spot2'] = ID_spot_2


#################
# write output
#################

# create header
args.out_file.write(auxilary_data['nucleus']  + '\t')
args.out_file.write(auxilary_data['distance'] + '\t')
args.out_file.write('\t'.join( [x.replace('zz','1') for x in auxilary_data['spot']] ) + '\t')
args.out_file.write('\t'.join( [x.replace('zz','2') for x in auxilary_data['spot']] ))
args.out_file.write('\n')

# data looks like:
# {    'dist_1_1_0_44_6_1_GFR': {    'GFR Spot Pairs - Bounding Box': '[114,69,122,86]',
#                                    'GFR Spot Pairs - Cell Count': '',
#                                    'GFR Spot Pairs - Cell Type': '',
#                                    'GFR Spot Pairs - Column': '1',
#      'nucleus': {    'Nuclei Selected - Bounding Box': '[99,59,128,99]',
#                      'Nuclei Selected - Cell Count': '',
#                      'Nuclei Selected - Cell Type': '',
#                      'Nuclei Selected - Column': '1',
#                      'Nuclei Selected - Compound': '',
#                      'Nuclei Selected - Concentration': '',
#                      'Nuclei Selected - Field': '44',
#      'spot_1_1_0_44_6_4_green': {    'ID_dist': [    '1_1_0_44_6_1_GR',
#                                                      '1_1_0_44_6_1_GFR'],
#                                      'green spots - Bounding Box': '[109,63,117,70]',
#                                      'green spots - Cell Count': '',
#                                      'green spots - Cell Type': '',
#                                      'green spots - Column': '1',
#                                      'green spots - Compound': '',
#                                      'green spots - Concentration': '',
#                                      'green spots - Corrected Spot Intensity': '1638.88',
#                                      'green spots - Field': '44',
#                                      'green spots - GFR_NucIndex': '6',
#                                      'green spots - GFR_Spot1Index': '1',
#                                      'green spots - GR_NucIndex': '6',

for nucleus in selected_data.keys():
    
    out_line = ['NA'] * 102
    current_write_index = 0
    # write nucleus characteristics & experiment name
    out_line[current_write_index] = selected_data[nucleus]['experimentID']
    current_write_index += 1
    
    nucleus_keys = selected_data[nucleus]['nucleus'].keys()
    for i in range( len(nucleus_keys) ):
        key = nucleus_keys[i]
        out_line[current_write_index] = selected_data[nucleus]['nucleus'][key]
        current_write_index += 1
    
    save_write_index = current_write_index
    save_out_line = copy.copy( out_line )
        
    # this may overwrite a copy of NA data, if multiple distance entries are present in one nucleus (which should happen often)
    for distance in selected_data[nucleus].keys():
        
        # pick out the distance data
        if distance.startswith('dist'):
            
            current_write_index = save_write_index
            out_line = copy.copy( save_out_line )
            
            # write out all the "distance" features
            distance_keys = selected_data[nucleus][distance].keys()
            for k in range( len(distance_keys) ):
                key = distance_keys[k]
                
                if not key.startswith('spot'): # leave out the spot IDs
                    # append to the existing out_line
                    out_line[current_write_index] = selected_data[nucleus][distance][key]
                    current_write_index += 1
            
            ID_spot_1 = selected_data[nucleus][distance]['spot1']
            ID_spot_2 = selected_data[nucleus][distance]['spot2']
            
            # check out the corresponding spot data
            for potential_spot in selected_data[nucleus].keys():
            # for potential_spot in [ID_spot_1, ID_spot_2]:
                
                # # if the current index is a spot, then check if it belongs to the distance under current investigation
                if potential_spot.startswith('spot'):
                    
                    # if this succeeds the spot belongs to the distance
                    if ID_spot_1 in selected_data[nucleus][potential_spot]['ID_dist'] or ID_spot_2 in selected_data[nucleus][potential_spot]['ID_dist']:
                        
                        # write spot data to collected line
                        spot_keys = selected_data[nucleus][potential_spot].keys()
                        
                        l = 0
                        for l in range( len(spot_keys) ):
                            key = spot_keys[l]
                            if not key == 'ID_dist':
                                # append to the existing out_line
                                out_line[current_write_index] = selected_data[nucleus][potential_spot][key]
                                current_write_index += 1
                        
                    # if does not belong to distance, check out next element
                    else:
                        continue
            
            args.out_file.write( '\t'.join(out_line) + '\n' )
    
    # what happens, if there are no "distance" entries?
    # there should be maximum 1 spot, because otherwise there would be a distance calculated
    # if there's no spot reported at all - this block will also report the empty nucleus
    if not any([ x.startswith('dist') for x in selected_data[nucleus].keys() ]):
        
        for potential_spot in selected_data[nucleus].keys():
            
            # set write index to 50, which is the index past distance fields
            current_write_index = 50
                
            # if the current index is a spot, write it to the output file
            if potential_spot.startswith('spot'):
                    
                # write spot data to collected line
                spot_keys = selected_data[nucleus][potential_spot].keys()
                
                l = 0
                for l in range( len(spot_keys) ):
                    key = spot_keys[l]
                    if not key == 'ID_dist':
                        # append to the existing out_line
                        out_line[current_write_index] = selected_data[nucleus][potential_spot][key]
                        current_write_index += 1
                    
                # if does not belong to distance, check out next element
                else:
                    continue
        
        args.out_file.write( '\t'.join(out_line) + '\n' )

# finish
sys.exit(0)
