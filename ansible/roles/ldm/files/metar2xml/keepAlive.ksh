#!/bin/ksh

# /home/ldm/var/data/surface/work/parseLoop.sh &

check=`ps -ef |grep parseLoop |grep -v grep |wc -l`

if [ $check -lt 1 ]; then
echo It is not running
date
echo starting
/home/ldm/var/data/surface/work/parseLoop.sh >> /tmp/parseLoop.log 2>>/tmp/parseLoop.err &

fi
