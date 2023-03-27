#!/bin/bash
# AUTHOR / DATE
# Vartika Bisht; March 22, 2023

##############################################
##############################################
########### SCALING AND NORALISING ###########
##############################################
##############################################
######## For each fragment i, we have ########
# Fragment | iPCR   |   cDNA-1  |  cDNA-2 .. #
#    i     | iPCR-i | cDNA-1 -i | cDNA-2-i ..#
##############################################
##############################################


## Normalisation.sh : Bash scipt for normalising 
## This script requires a file with total counts across all chromosomes ( total counts - iPCR and cDNA ), 
## column name of the cDNA samples, column name of the iPCR sample, column name of the SNP position field,
## and a tab seperated file with all the columns specified above.
## 


## bash ScalenNormalise.sh -f 'exploded.file.txt.gz' -i 'count' -c 'cDNA1 cDNA2' -s 'SNP_ABS_POS' -o norm.out.txt.gz -t total.count.txt


OPTIND=1         

SCRIPTNAME="ScalenNormalise.sh"

#Default
prefix=ipcr.norm.sum

# Usage 
USAGE=
usage() {
  echo >&2 "usage: ${SCRIPTNAME} -?:h:f:c:i:s:p:t:o:"
  echo >&2 "OPTIONS:"
  echo >&2 "  -f: SuRE Count file of the format .gz [required]"
  echo >&2 "  -c: Names of the cDNA columns [required]"
  echo >&2 "  -i: Names of the iPCR column [required]"
  echo >&2 "  -s: Names of the SNP position column [required]"
  echo >&2 "  -p: prefix for normalised cDNA columns"
  echo >&2 "  -t: Total count file, txt file [required]"
  echo >&2 "  -o: output file, in gz format [required]"
  echo >&2 "  -h: print this message"
  echo >&2 ""
  exit 1;
}
# Opts
while getopts "?:h:f:c:i:s:t:o:" opt; do
  case $opt in
    f)
      file=$OPTARG;
      ;;
    c)
      cDNA=$OPTARG;
      ;;
    i)
      iPCR=$OPTARG;
      ;;
    s)
      snppos=$OPTARG;
      ;;
    t)
      totalcount=$OPTARG;
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

function join_by {
  local d=${1-} f=${2-}
  if shift 2; then
    printf %s "$f" "${@/#/$d}"
  fi
}

## Remove all rows without mutations
echo "Remove all fragments without any mutations.."
snpposcolnum=($(head -1  <(zcat $file) | sed 's/\t/\n/g' | nl | grep $snppos | awk '{print $1}'))
awk -vFS="\t" -vOFS="\t" -vsnpposcolnum=$snpposcolnum '$snpposcolnum != ""' <(zcat $file) | gzip -c - > $TMP/rm_noMut.txt.gz
file=$TMP/rm_noMut.txt.gz
echo "Ready to process!"

echo "To scale the data for processing, we divide iPCR and cDNA counts by their respective depths, i.e. Total_iPCR and Total_cDNA-1,Total_cDNA-2,Total_cDNA-3 ... "
echo "To normalise the enrichment for each fragment, we divide scaled cDNA by scaled iPCR for each fragment.."
echo "Hence, for each fragments i, the scaled and normalised enrichment wrt cDNA sample k, can be written as (cDNA-k-i/iPCR-i) * (Total_cDNA-k/Total_iPCR) "

## Define the multiplication factor
echo "Total_cDNA-k/Total_iPCR can be interpreated as a multiplication factor for cDNA sample k"
echo "Calculating multiplication factor for all cDNA samples.."
ipcrcolnum=($(head -1   $totalcount | sed 's/\t/\n/g' | nl | grep $iPCR | awk '{print $1}'))
ipcr_total=($(awk -vFS="\t" -vipcrcolnum=$ipcrcolnum 'NR>1{print $ipcrcolnum}' $totalcount))
## Make sure that the relative order of cDNA names in $totalcount is the same as it is in $file.
## Determine the cDNA column number in the file
cDNAcolnum=()
for col in $cDNA
do
  colnum=($(head -1 <(zcat $file) | sed 's/\t/\n/g' | nl | grep $col | awk '{print $1}'))
  cDNAcolnum+=($colnum)
done
## Rearrage $totalcount
cut -d$'\t' -f${ipcrcolnum} $totalcount > $TMP/Rearrage_totalcount.txt
for col in $(head -n1 <(cut -d$'\t' -f$(join_by , "${cDNAcolnum[@]}") <(zcat $file)))
do
    colnum=($(head -1 $totalcount | sed 's/\t/\n/g' | nl | grep $col | awk '{print $1}'))
    paste -d$'\t' <(cat $TMP/Rearrage_totalcount.txt) <(cut -d$'\t' -f$colnum $totalcount) > tmp
    mv tmp $TMP/Rearrage_totalcount.txt
done
# write multiplication factor as total iPCR / total cDNA in a file for each cDNA 
awk -vFS="\t" -vOFS="\t" -vipcr_total=$ipcr_total 'NR==1 {$0} ;NR>1{for(i=1;i<=NF;++i){$i = ipcr_total/$i }}1' <(cut -d$'\t' --complement -f1 $TMP/Rearrage_totalcount.txt) > $TMP/MF.txt
echo "Multiplication factor for all cDNA samples calculated."

## Normalise cDNA and add new column 
echo "Starting normalisation.."
echo "First, dividing cDNA count by iPCR count for each fragment wrt each cDNA sample (cDNA-k-i/iPCR-i) .."
## Determine the iPCR column number in the file
ipcrcolnum=($(head -1   <(zcat $file) | sed 's/\t/\n/g' | nl | grep $iPCR | awk '{print $1}'))

## Subset the file to only have iPCR and cDNA columns
## The first column will be the iPCR column and all the other would be cDNA
## The relative order amongst the cDNA samples is the same as in the original file.
paste -d$'\t' <(cut -d$'\t' -f$ipcrcolnum <(zcat $file)) <(cut -d$'\t' -f$(join_by , "${cDNAcolnum[@]}") <(zcat $file)) > $TMP/subset_file.txt

## Divide cDNA by iPCR for all rows.
awk -vFS="\t" -vOFS="\t" -vprefix=$prefix 'NR==1 {for(i=2;i<=NF;++i){$i = prefix"."$i}} ;NR>1{for(i=2;i<=NF;++i){$i = $i/$1}}1' $TMP/subset_file.txt | cut -d$'\t' -f2- - > $TMP/${prefix}.file.txt


echo "Now, multiplying the multiplication factor to each cDNA sample as calculated previously, i.e. (cDNA-k-i/iPCR-i)  * (Total_cDNA-k/Total_iPCR) "
## The relative order of columns in the MF.txt and ${prefix}.file.txt is same.
## $TMP/${prefix}.file.txt has the same relative order as original file.
## We have already rearrange $TMP/MF.txt to have same order as original file.
## Multiple the respective multiplication factors and add these columns to the file
paste -d$'\t' <(zcat $file) <(cat <(head -n 1 $TMP/${prefix}.file.txt) <(awk -vFS="\t" -vOFS="\t" 'NR==1{cols = split($0,m);next}; NR>1{for(i=1; i<=NF; i++){$i = sprintf("%.5f", $i*m[i])}}1' <(tail -n +2 $TMP/MF.txt) <(tail -n +2 $TMP/${prefix}.file.txt))) | gzip -c - > $outfile


echo "Normalisation done."
echo "Normalised file saved to" $outfile