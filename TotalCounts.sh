#!/bin/bash
# AUTHOR / DATE
# Vartika Bisht; March 22, 2023


######################################
######################################
###### CALCULATING TOTAL COUNTS ######
######################################
######################################
#### |  COL1  |  COL2  |  COL3  | ####
#### |   V1   |   V3   |   V6   | ####
#### |   V2   |   V4   |   V5   | ####
######################################
######################################
## Sum of counts for COL1 and COL2 ###
####### |  COL1   |  COL2   |  #######
####### |  V1+V2  |  V3+V4  |  #######
######################################
######################################


## TotalCounts.sh : Bash scipt for calculatiing total counts.
## This scripts takes a tab seperated file and relavent column names as input.
## It then subsets each file to include only the specified columns and then add all the rows for each column. This is then saved in a temp file. A new row is added for each file.
## Finally, you sum all columns in the temp file and write it as a tab seperated file.

## Input File Format:
## Tab seperated file
## Column names as the first row of the file
## Colnames specified in the -c flag of TotalCounts.sh must exist is all files specified under -f
## You can provide chromosome wise input or a combined dataframe with all chomosome.

## Output File Format:
## Tab seperated file
## Column names as the first row of the file
## Colnames in the same order as specified in the -c flag of TotalCounts.sh

## bash TotalCounts.sh -f 'Input.txt.gz' -c 'COL1 COL2' -o Output.txt

OPTIND=1         

SCRIPTNAME="TotalCounts.sh"

# Usage 
USAGE=
usage() {
  echo >&2 "usage: ${SCRIPTNAME} -?:h:f:c:o:"
  echo >&2 "OPTIONS:"
  echo >&2 "  -f: Tab seperated file of the format .gz [required]"
  echo >&2 "  -c: Names of the column for total counts calculation [required]"
  echo >&2 "  -o: output file [required]"
  echo >&2 "  -h: print this message"
  echo >&2 ""
  exit 1;
}
# Opts
while getopts "?:h:f:c:o:" opt; do
  case $opt in
    f)
      file+=("$OPTARG");
      ;;
    c)
      colname=$OPTARG;
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


 # https://dev.to/meleu/how-to-join-array-elements-in-a-bash-script-303a
 # First argument is delimiter to be seperated with, all the other arguments are 
 # entries to be joined by the first argument. d and f will exist only locally, and
 # when unset would become null. Shift the list of argument by 2, skipping $1 and $2
 # which are now $d and $f respectively. Write $2, then $1, then for all ${@}, $# will
 # first add $d ( delimiter ) before all the variable in $@ - $3,$4 ....
 # $@ expands positional argument with just a space , rather than IFS in case of $*
 # $# defines the pattern to be replaced only if the variable starts with the pattern
function join_by {
  local d=${1-} f=${2-}
  if shift 2; then
    printf %s "$f" "${@/#/$d}"
  fi
}

# Create an empty temp file with just the header
IFS=', ' read -r -a colname_array <<< "$colname"
header=$(IFS=, ; echo "${colname_array[*]}")
temp=$TMP/outfile.txt
echo $header > $temp

# Iterate through all the files, sum the column of interest, add the values to the temp file.
for f in $file
do
  echo processing file $(basename $f) ..
  colsum_array=()
  for col in $colname
  do
    colnum=($(head -1  <(zcat $f) | sed 's/\t/\n/g' | nl | grep $col | awk '{print $1}'))
    sum=$(cut -d$'\t' -f"$colnum" <(zcat $f) | tail -n +2 - | paste -sd+ | bc )
    colsum_array+=($sum)
  done
  echo $(join_by , "${colsum_array[@]}") >> $temp
done

# Add up
cat <(head -n 1 $temp)  <(awk -vFS="," -vOFS="," '{for(i=1;i<=NF;i++)$i=(a[i]+=$i)}END{print}' <(tail -n +2 $temp)) | awk -vFS="," -vOFS="\t" '$1=$1' -  > $outfile
