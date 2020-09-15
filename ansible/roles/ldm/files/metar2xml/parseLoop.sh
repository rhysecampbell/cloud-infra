#!/bin/sh

path=/home/ldm/var/data/surface/work

while true; do

date=`date +%Y.%m.%d-%H%M.%N`

if [[ -f $path/stop.txt ]]; then
exit

else

$path/parseAll.pl > /home/ldm/var/data/surface/work/log/$date.log 2>/home/ldm/var/data/surface/work/log/$date.err

if ! [ `find "$path/sendcc-completed" -type d -empty` ]; then
mv $path/sendcc-completed $path/upload-archive/$date
mkdir $path/sendcc-completed
fi


fi
done
