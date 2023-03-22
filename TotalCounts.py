# AUTHOR / DATE
# Vartika Bisht; May 18, 2021; TotalCounts.py

## This script calculates the total iPCR and cDNA counts for a library
## The script saves the total counts in a text file.

# USAGE / INPUT / ARGUMENTS / OUTPUT

# USAGE:

# required:
#   -i : List of all SuRE counts file for one library
#   -c : list of cDNA column names and iPCR column name
#   -o : output directory
#   -l : log file name

# INPUT:
#   -i : List of all SuRE counts file for one library


# ARGUMENTS:
#   -c : list of cDNA column names and iPCR column name
#   -l : log file name

# OUTPUT:
#   -o : output filename

# Libraries
import os
import sys
import pandas as pd
import logging
import argparse

SCRIPTNAME = "TotalCounts.py"

def parse_options():
    # parse user options:
    # Print the help message if no arguments are supplied
    parser = argparse.ArgumentParser( description='''Calculate Total Counts for a genome.''')

    parser.add_argument('-i','--input',help='SuRE counts file for all chromosomes',required=True, nargs = '+')
    parser.add_argument('-c', '--cols', help='list of cDNA column names and iPCR column name',
                        required=True, nargs = '+')
    parser.add_argument('-o','--output' , help='Output file name' , required=True)
    parser.add_argument('-l', '--log' , help='log file name' , required=True)
    args = parser.parse_args()
    return args


def init_logger(args):
    # Simply create the directory path which will contain outputfile; this operation will not destroy anything
    dir = os.path.dirname(args.output)
    os.makedirs(dir,exist_ok=True)
    # setup a logger 'object'
    logger = logging.getLogger(__name__)
    logger.setLevel(logging.DEBUG)
    # formatter; prints: logger-name, logging-level, time, module(scriptfile)name, line nr, msg
    formatter = logging.Formatter('%(name)s:%(levelname)s:%(asctime)s:%(module)s:%(lineno)d - %(message)s',
        datefmt='%d-%b-%y %H:%M:%S')
    # add the log file as handler
    fh = logging.FileHandler(args.log, mode='w')
    fh.setLevel(logging.DEBUG)
    fh.setFormatter(formatter)
    # add terminal console as handler
    ch = logging.StreamHandler()
    # only output error to stdout
    ch.setLevel(logging.ERROR)
    ch.setFormatter(formatter)
    # add the handlers to the logger object
    logger.addHandler(fh)
    logger.addHandler(ch)
    return logger

# Calculating total counts
def totalcount(args):
    logger = logging.getLogger(__name__)
    logger.info("Calculating Total counts - START")
    # col names
    colnames = args.cols[0].split(" ")
    # List of counts table
    cf_list = args.input[0].split(" ")
    # Initialise a dataframe to keep track of the sum
    TC = pd.DataFrame(0 , index = colnames, columns = ["SUM"])
    # Loop through the chromosomes
    for i in cf_list:
        # Load one chromosomal SuRE counts file
        # Only load the columns needed
        logger.info("Loading in {}".format(i))
        SuRE_CF = pd.read_csv( i ,usecols=colnames,header=0,sep='\t')
        # Calculate the sum of all the columns in one go and store as list
        SuRE_CF_sum = [sum(SuRE_CF[x]) for x in SuRE_CF.columns]
        # Update the sum dataframe using the sum list
        for k,j in enumerate( SuRE_CF.columns):
            TC["SUM"][j] += SuRE_CF_sum[k]

    logger.info("Calculating Total counts - DONE")
    return TC


def write_TC(TC,fname):
    # Save as txt file to be used in futher analysis
    TC.to_csv(fname, sep='\t')

def main(args):
    # Open log file
    init_logger(args)
    # Calculating total counts
    TC = totalcount(args)
    # Write outputs
    write_TC(TC,args.output)
    return


if __name__ == "__main__":
    sys.stderr.write("command: %s\n" % " ".join(sys.argv))
    args = parse_options()
    main(args)
