#!/bin/sh

date=$1

path=/var/www/html/error-scripts/errorLogs

for i in `ls -S $path/$date`; do echo $i| tr -d "\n"; echo ' ' | tr -d "\n"; grep BEGIN $path/$date/$i |wc -l; done
