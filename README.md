# Roslin_Deliverables

This repository consists deliverable scripts for Roslin Institute



## TotalCounts.sh : Bash scipt for calculatiing total counts.
```
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
```
This scripts takes a tab seperated file and relavent column names as input.
The script first subsets the/each file to include only the specified columns and then adds all the rows for each column.
If you supply multiple files, the sum of columns from each file is added to a temp file. After iterating through all file, the rows of the temp file are added column wise and the output is written as a tab seperated file.
```
bash TotalCounts.sh -f 'Input.txt.gz' -c 'COL1 COL2' -o Output.txt
```

## Normalisation.sh : Bash scipt for normalising 
```
##############################################
##############################################
########### SCALING AND NORALISING ###########
##############################################
##############################################
######## For each fragment i, we have ########
# Fragment | iPCR   |   cDNA-1  |  cDNA-2 .. #
#    i     | iPCR-i |  cDNA-1-i | cDNA-2-i ..#
##############################################
##############################################
#### For library, we have Total.Count.txt ####
#    iPCR    |    cDNA-1    |    cDNA-2 ..   #
# Total_iPCR | Total_cDNA-1 | Total_cDNA-1 ..#
##############################################
##############################################
##### To scale and normalise enrichment ######
######## For each fragment i we do, ##########
## Fragment |          cDNA-1        | .... ##
##          |  cDNA-1-i * Total_iPCR | .... ##
##    i     |  --------------------- | .... ##
##          |  iPCR-i * Total_cDNA-1 | .... ##
##############################################
##############################################
##############################################
##############################################
```
This script requires a file with total counts across all chromosomes ( total counts - iPCR and cDNA ), column name of the cDNA samples, column name of the iPCR sample, column name of the SNP position field (this is use to subset the dataset , to ease the computation process), and a tab seperated file with all the columns specified above.
The script first subsets the tab seperated file to only include fragments with mutations. This is computationally efficient as the complexity of the script is directly proportional to the number of rows in the tab seperated input file O(n). Then it calculates a multiplication factor which is total iPCR / total cDNA for each cDNA replicate/sample. This makes the whole process of normalising and scaling easier. Then the script divides cDNA by iPCR for each fragment, and multiplies by the multiplication factor, in the end , resulting in a formula (cDNA-k-i/iPCR-i) * (Total_iPCR/Total_cDNA-k).
```
bash ScalenNormalise.sh -f Input.txt.gz -i 'iPCR' -c 'cDNA-1 cDNA-2' -s 'COL3' -o Output.txt.gx -t Total.Count.txt
```

## ExplodeDataframe.sh : Bash scipt for exploding dataframe

```
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
```

The script required tab seperated file and list of columns which need to be exploded. This script first determine the column numbers of the column names specified for exploding. It then splits the dataframe into rows which have to be exploded and which need no exploding to make the computation easier. Then, it iteratively goes through all the columns which have to be exploded and does it for each row. Lastly, it joins the exploded dataframe with the data frame which need no exploding and finaly removes duplicated rows.

```
bash ExplodeDataframe.sh -f 'Input.txt.gz' -c 'COL1 COL2 COL3' -o Output.txt.gz
```
 
