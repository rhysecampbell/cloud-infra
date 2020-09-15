#!/bin/ksh

# splits up single METAR files into multiple files
# 300 lines in length, with the final file being
# what's left over.  This was needed since sendcc
# will time-out if the transmission of a file
# is too large.

path=/home/ldm/var/data/surface/work

typeset -RZ2 section

for file in `ls $path/python/outputdir`
do

while read line           
do
	let count=$count+1
	section=`expr $count / 300`
	echo $line >> $path/carved/$file.$section
done < $path/python/outputdir/$file

count=0
done

# temporary archive metars

if ! [ `find "$path/carved" -type d -empty` ]; then
sleep 1
# export GZIP=-9
date=`date +%Y.%m.%d`
cat $path/carved/* >> $path/metarchive/$date.METARS
#tar -rf $path/metarchive/$date.tar $path/carved
fi
