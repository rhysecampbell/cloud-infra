#!/bin/sh

# clean up the DQM logs older than 1 week old

for i in `find /var/www/html/error-scripts/results -maxdepth 1 -mtime +7`; do
rm -rf $i
done

for i in `find /var/www/html/error-scripts/errorsBySite -maxdepth 1 -mtime +7`; do
rm -rf $i
done

for i in `find /var/www/html/error-scripts/errorLogs -maxdepth 1 -mtime +7`; do
rm -rf $i
done
