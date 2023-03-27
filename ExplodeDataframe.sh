#!/bin/bash
# AUTHOR / DATE
# Vartika Bisht; March 22, 2023


######################################
######################################
######## EXPLODING DATAFRAMES ########
######################################
######################################
######### Original DataFrame #########
#### |  COL1  |  COL2  |  COL3  | ####
#### |  V1,V2 |   V3   | V4,V5  | ####
######################################
######################################
######### Exploded DataFrame #########
#### |  COL1  |  COL2  |  COL3  | ####
#### |   V1   |   V3   |   V4   | ####
#### |   V2   |   V3   |   V5   | ####
######################################
######################################
######################################
######################################

## ExplodeDataframe.sh : Bash scipt for exploding dataframe
## The script required tab seperated file and list of columns which need to be exploded.
## This script first determine the column numbers using the column names specified for exploding.
## It then splits the dataframe into rows which have to be exploded and which need no exploding.
## Then, it iteratively goes through all the columns which have to be exploded and do it for each rows.
## Lastly, it joins the exploded dataframe with the data frame which need no exploding and finaly removes duplicates.

## An assumption for such explosion is that the comma seprated entries in each row are the same, 
## i.e , the length of the comma seprated list for all columns in a row is same. ( as shown above)
## i.e , in the above example : number of elements in COL1 - V1,V2 anf COL2 - V4,V5 must be same.

## Input File Format:
## Tab seperated file
## Column names as the first row of the file
## Colnames specified in the -c flag of ExplodeDataframe.sh must exist is all files specified under -f

## Output File Format:
## Tab seperated file
## Column names as the first row of the file

## bash ExplodeDataframe.sh -f 'SuRE_file.txt.gz' -c 'SNP_ABS_POS SNP_SEQ SNP_PARENT SNP_VAR SNP_TYPE SNP_SUBTYPE SNP_ABS_POS_hg19 SNP_ID' -o outfile.txt.gz


OPTIND=1         

SCRIPTNAME="ExplodeDataframe.sh"

# Usage 
USAGE=
usage() {
  echo >&2 "usage: ${SCRIPTNAME} -?:h:f:c:o:"
  echo >&2 "OPTIONS:"
  echo >&2 "  -f: Tab seperated file of the format .gz  [required]"
  echo >&2 "  -c: Names of the columns with comma seperated files which have to be exploded [required]"
  echo >&2 "  -o: output file, in gz format [required]"
  echo >&2 "  -h: print this message"
  echo >&2 ""
  exit 1;
}
# Opts
while getopts "?:h:C:f:c:o:" opt; do
  case $opt in
    f)
      file=$OPTARG;
      ;;
    c)
      commacols=$OPTARG;
      ;;
    o)
      outfile=$OPTARG;
      ;;
    h)
      usage;
      ;;
    \?)
      echo "option not recognized: "$opt
      usage
      ;;
  esac
done
shift $(( OPTIND - 1 ))

#Check if output dir exists, if not, then create it
outdir="$(dirname "$outfile")"
if [ -d $outdir ] 
then
    echo "$outdir directory exists." 
else
    mkdir $outdir
    echo "$outdir directory does not exists, now it is created."
fi


function join_by {
  local d=${1-} f=${2-}
  if shift 2; then
    printf %s "$f" "${@/#/$d}"
  fi
}

# Determine the column numbers usinh the column names
# Store it the commacolsnums variable
commacolsnums=()
for col in $commacols
do
    colnum=($(head -1  <(zcat $file) | sed 's/\t/\n/g' | nl | grep $col | awk '{print $1}'))
    commacolsnums+=($colnum)
done

echo "Preparing dataframe for explosion ..."

# Split the dataframe into two
# Dataframe with rows to be exploded
cat <(zcat $file | head -n 1)  <(gawk -vcommacheck=${commacolsnums[0]} '{if($commacheck ~ /,/ ){print $0}}' <(zcat $file | tail -n +2)) > $TMP/commasubset.txt
# Dataframe with no rows to be exploded
gawk -vcommacheck=${commacolsnums[0]} '{if($commacheck !~ /,/ ){print $0}}' <(zcat $file | tail -n +2) > $TMP/non_commasubset.txt



# The columns without comma are concatenated with the delimiter "|" and together form the first column
# 2,3,4...NF columns have comma seperated values.
# Say, you have 3 columns wuth 4 values, such that last column has comma seperated values, this step would: V1 V2 V3,V4 --> V1|V2 V3,V4
paste -d$'\t' <(cut --complement -d$'\t' -f$(join_by , "${commacolsnums[@]}" ) $TMP/commasubset.txt | awk -vFS="\t" -vOFS="|" '$1=$1' -) \
     <(cut -d$'\t' -f$(join_by , "${commacolsnums[@]}" ) $TMP/commasubset.txt) > $TMP/ready_to_explode_commasubset.txt

echo "Ready to explode!"

# We exploded columns 2,3,4...NF.
# First split all columns with commas, then write them down in seperate rows with the 1st column same.
# The Output field sep has been changed to "|" , so that all rows are now seperated by delimiter |
# We can then change the delimited from "|" to "\t"
awk -vFS="\t" -vOFS="|" '{
    n=0;
    for(i=2;i<=NF;i++) {
        t=split($i,a,",");if(t>n) n=t};
    for(j=1;j<=n;j++) {
        printf "%s",$1;
        for(i=2;i<=NF;i++) {
            split($i,a,",");printf "|%s",(a[j]?a[j]:a[1])
            };
        print ""
        }
    }' $TMP/ready_to_explode_commasubset.txt > $TMP/exploded_commasubset.txt

# Concatenate the exploded subset with the non comma subset
# Make sure that the relative column numbers are same
paste -d$'\t' <(cut --complement -d$'\t' -f$(join_by , "${commacolsnums[@]}" ) $TMP/non_commasubset.txt ) \
     <(cut -d$'\t' -f$(join_by , "${commacolsnums[@]}" ) $TMP/non_commasubset.txt) > $TMP/ordered_non_commasubset.txt

cat <(awk -vOFS="\t" -vFS="|" '$1=$1' $TMP/exploded_commasubset.txt) $TMP/ordered_non_commasubset.txt | awk -vFS="\t" -vOFS="\t" '!seen[$0]++' - | gzip -c - > $outfile

echo "Your dataframe is exploded, duplicated rows have been removed and the final file is written to" $outfile