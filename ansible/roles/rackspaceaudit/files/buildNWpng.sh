#!/bin/bash

path='/var/www/html/securityReports/network/systemNets'

cd $path
for file in `ls *.diag`; do
/usr/bin/nwdiag $file
done

