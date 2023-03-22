# AUTHOR / DATE
# Vartika Bisht; May 17, 2021; Normalisation.py

## Normalising SuRE counts file.
## Before normalisation, we seprate multiple mutations 
## on a single fragment in a way so that each row entry contains
## information for one SNP per fragment. Then we scale each
## cDNA and iPCR wrt total cDNA and iPCR counts/reads respectively.
## Then finally, we normalise scaled cDNA be iPCR .

# USAGE / INPUT / ARGUMENTS / OUTPUT

# USAGE:

# required:
#   -i : SuRE counts file 
#   -tc : total count 
#   -l : log file name
#   -o : Output filename

# INPUT:
#   -i : SuRE counts file

# ARGUMENTS:
#   -tc : Total count file path
#   -l : Log file name 
#   -lib : Name of the library being processed  


# OUTPUT:
#   -o : Output filename


# Libraries
import os
import sys
import pandas as pd
import logging
import argparse
import numpy as np

SCRIPTNAME = "Normalisation.py"

def parse_options():
    # parse user options:
    # Print the help message if no arguments are supplied
    parser = argparse.ArgumentParser(description='''Normalising SuRE counts file per genome
    for one chromosome.''')
    parser.add_argument('-i', '--input', help='SuRE counts file', required=True)
    parser.add_argument('-tc', '--tc', help='Total count file path', required=True)
    parser.add_argument('-o', '--output', help='Output file name', required=True)
    parser.add_argument('-l', '--log', help='Log file name', required=True),
    parser.add_argument('-lib', '--library', help='Library name', required=True)
    args = parser.parse_args()
    return args

# This variable needs to be defined to make sure we explode the dataframe properly.
# The following columns have comma seperated values which correspond to multiple mutataions in a single fragment
comma_columns = ['SNP_ABS_POS', 'SNP_SEQ', 'SNP_PARENT', 'SNP_VAR', 'SNP_TYPE','SNP_SUBTYPE', 'SNP_ABS_POS_hg19']

# Read and reformat the counts file, so that the multiple muattaions in a single fragments are read properly.
def read_reformat_SuRE_counts_file(args):
    logger = logging.getLogger(__name__)
    logger.info("Reading SuRE counts file")
    df = pd.read_csv(args.input, compression='gzip', header=0, sep="\t")
    df_comma_row = list(df[df['SNP_ABS_POS_hg19'].astype(str).str.contains(",", na=False)].index)
    for i in comma_columns:
        df[i].iloc[df_comma_row] = df[i].iloc[df_comma_row].apply(lambda x: x.split(','))
    return df


# Total counts calculated using TotalCounts.py
def totalcounts(args):
    tc_df = pd.read_csv(args.tc, sep='\t', index_col=0)
    return tc_df


# Logger
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

# Explode the entire df
def reformat(df):
    logger = logging.getLogger(__name__)
    logger.info("Reformatting SuRE table to have one SNP per read - STARTED")
    # Explode with respect to all columns
    # Add index to keep track of explosion
    df['index'] = range(df.shape[0])
    nan_value = float("NaN")
    df.replace("nan", nan_value, inplace=True)
    # We do not want to retain fragments with no mutation
    df.dropna(subset=["SNP_VAR"], inplace=True)
    # Explode in series using df.index refrence, then resent index and remove the refrence (df.index)
    logger.info("Exploding SuRE table")
    exploded_df = df.set_index(['index']).apply(pd.Series.explode).reset_index().drop('index', axis=1)
    logger.info("Exploding done")
    # Remove duplicate entries due to paired end
    logger.info("Dropping duplicates if any")
    exploded_df_no_dups = exploded_df.drop_duplicates()
    logger.info("Reformatting SuRE table to have one SNP per read - DONE")
    return exploded_df_no_dups


def normalize(df, tc_df):
    # Explode the
    logger = logging.getLogger(__name__)
    logger.info("Normalising SuRE table - STARTED")
    ipcr_sum = tc_df["SUM"]['count']
    tc_df = tc_df.drop('count', axis=0)
    exploded_df = reformat(df)
    for i in tc_df.index:
        # Normalisation scheme : cdna_norm_i = cdna_raw_i/ipcr_raw_i * (ipcr_raw_total/cdna_raw_total)
        # multiplication factor (ipcr_raw_total/cdna_raw_total)
        mf = ipcr_sum/tc_df["SUM"][i]
        norm_cDNA_col_name = "ipcr.norm.sum.{}".format(i)
        # Express cDNA as read per billion, rounded to whole integers
        exploded_df[norm_cDNA_col_name] = (exploded_df[i]/exploded_df["count"])*mf
    logger.info("Normalising SuRE table - DONE")
    return exploded_df

def lib_info(df,library):
    # Add library name
    df["Lib"] = np.repeat(library,df.shape[0],axis =0)
    return df

# Write output
def write_output(df,fname):
    df.to_csv(fname, compression="gzip", sep = "\t",index=False)


def main(args):
    # Open log file
    logger = init_logger(args)
    # Load the arguments
    SuRE_df = read_reformat_SuRE_counts_file(args)
    # Load total counts
    tc_df = totalcounts(args)
    # Normalisation
    nSuREdf = normalize(SuRE_df, tc_df)
    # Add library information
    nSuREdf = lib_info(nSuREdf,args.library)
    # Write output
    write_output(nSuREdf,args.output)
    return


if __name__ == "__main__":
    sys.stderr.write("command: %s\n" % " ".join(sys.argv))
    args = parse_options()
    main(args)
