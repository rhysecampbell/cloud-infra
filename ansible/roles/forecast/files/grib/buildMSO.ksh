#!/bin/ksh

# 2015.01.14  - updated code to accommodate new filename structure of GFS files - JESP
#   old
#     http://www.ftp.ncep.noaa.gov/data/nccf/com/gfs/prod/gfs.2015011312/gfs.t12z.pgrb2f06
#
#   new
#     http://www.ftp.ncep.noaa.gov/data/nccf/com/gfs/para/gfs.2015011312/gfs.t12z.pgrb2.0p50.f006
#



# force 2 digit for some variables which need to be padded with zeros if not 2 digits already
typeset -RZ3 forecastHour
typeset -RZ2 run
typeset -RZ2 instance

# define # of simultaneous buildMSO processes to run
export OMP_NUM_THREADS=1

# get current date
date=`date +%Y%m%d`

# get the value of the run 3 hours ago.
# it will always be positive, since the cron runs
# at 3,9,15,21 hour
let run=`date +%H`-4

# date=20150113
# run=12
# ie: gfs.t12z.pgrb2f06
# shows up at 15:23 - 15:47


path=/home/data/grib2obs/GRIB

# cleanup previous GRIB processing files
rm -rf $path/??????????.originalGRIB
rm -rf $path/??????????.trimmedGRIB
rm -rf $path/??????????.trimmedASCII
rm -f $path/sendcc-sent/*.xml

# create the directories for the next run
mkdir $path/${date}$run.originalGRIB
mkdir $path/${date}$run.trimmedGRIB
mkdir $path/${date}$run.trimmedASCII
mkdir $path/${date}$run.mso
mkdir $path/${date}$run.xml

# grab the forcast files between 06 and 78 (25 total, 3 days out)
for forecastHour in $(seq 6 3 78)
 do

wget -P $path/${date}$run.originalGRIB http://www.ftp.ncep.noaa.gov/data/nccf/com/gfs/prod/gfs.${date}$run/gfs.t${run}z.pgrb2.0p50.f$forecastHour

done


# create trimmed GRIBs containing only what we need
 for file in `ls $path/${date}$run.originalGRIB`; do
$path/bin/wgrib2 $path/${date}$run.originalGRIB/$file -match ':TMP:2 m above ground:' -grib $path/${date}$run.trimmedGRIB/$file -set_grib_type jpeg
$path/bin/wgrib2 $path/${date}$run.originalGRIB/$file -match ':UGRD:10 m above ground:' -append -grib $path/${date}$run.trimmedGRIB/$file -set_grib_type jpeg
$path/bin/wgrib2 $path/${date}$run.originalGRIB/$file -match ':VGRD:10 m above ground:' -append -grib $path/${date}$run.trimmedGRIB/$file -set_grib_type jpeg
$path/bin/wgrib2 $path/${date}$run.originalGRIB/$file -match ':low cloud layer:' -append -grib $path/${date}$run.trimmedGRIB/$file -set_grib_type jpeg
$path/bin/wgrib2 $path/${date}$run.originalGRIB/$file -match ':middle cloud layer:' -append -grib $path/${date}$run.trimmedGRIB/$file -set_grib_type jpeg
$path/bin/wgrib2 $path/${date}$run.originalGRIB/$file -match ':high cloud layer:' -append -grib $path/${date}$run.trimmedGRIB/$file -set_grib_type jpeg
$path/bin/wgrib2 $path/${date}$run.originalGRIB/$file -match ':RH:2 m above ground:' -append -grib $path/${date}$run.trimmedGRIB/$file -set_grib_type jpeg
$path/bin/wgrib2 $path/${date}$run.originalGRIB/$file -match ':PRATE:surface:' -append -grib $path/${date}$run.trimmedGRIB/$file -set_grib_type jpeg
$path/bin/wgrib2 $path/${date}$run.originalGRIB/$file -match ':CSNOW:surface:' -append -grib $path/${date}$run.trimmedGRIB/$file -set_grib_type jpeg
$path/bin/wgrib2 $path/${date}$run.originalGRIB/$file -match ':GUST' -append -grib $path/${date}$run.trimmedGRIB/$file -set_grib_type jpeg
$path/bin/wgrib2 $path/${date}$run.originalGRIB/$file -match ':DLWRF' -append -grib $path/${date}$run.trimmedGRIB/$file -set_grib_type jpeg


# DPT to show up  CHECK THIS
# $path/bin/wgrib2 $path/${date}$run.originalGRIB/$file -match ':DPT:2 m above ground:' -grib $path/${date}$run.trimmedGRIB/$file -set_grib_type jpeg
# $path/bin/wgrib2 $path/${date}$run.originalGRIB/$file -match ':total cloud layer:' -append -grib $path/${date}$run.trimmedGRIB/$file -set_grib_type jpeg



# create the ASCII file from previous trimmed GRIB file, for processing
$path/bin/wgrib2 $path/${date}$run.trimmedGRIB/$file -csv $path/${date}$run.trimmedASCII/$file
done


# create the mso and xml files via the buildMSO.pl script, with 4 parallel instances (last value: 4)
# (seq 1 1 X) where X = # of threads
for instance in $(seq 1 1 1)
 do
 nice $path/buildMSO.pl ${date}$run $instance &
done

# Done starting all instances of buildMSO.pl
# Give the first instance file a few seconds (42) to show up.  Then check for instance files every 9 seconds.
# When they're all gone, do the sendcc
sleep 42

while true; do
if [ "$(ls -A $path/build-running)" ]; then
	echo "Still building files.  Checking again in 9 seconds.."
	date
	sleep 9
else
	echo "Done building files!"
	echo "Bail from loop and run sendcc!"
	date
	cp $path/${date}$run.xml/*.xml $path/ready4sendcc
	sleep 1
	$path/bin/sendcc -c grib.conf
	echo "sendcc done!"
	date
	# send the special China MSO file
	/usr/bin/scp $path/${date}$run.mso/BJTDJA_MXQ.mso forecast@nagmon.cloud.vaisala.com:/home/forecast/China/BTMB/BJ001.MSO
	exit
fi
done
