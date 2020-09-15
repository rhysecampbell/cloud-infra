#!/bin/sh

date=$1

path="/var/www/html/error-scripts/errorsBySite"


for file in `ls $path/$date`; do
newName=`echo $file|sed s/ERROR__//g`

cat $path/$date/$file | sort -u > $path/$date/$newName

rm -f $path/$date/$file

done
