#!/bin/bash
critical=
for i in /var/local/{image,rwis}/*/
do
        total=$(find $i 2>/dev/null | wc -l)
        if (( "$total" > 1000 ))
        then
                echo -n "CRITICAL - $i has $total files. "
                critical=yes
        fi
done

if [[ -z $critical ]]
then
        echo "OK"
        exit 0
else
        exit 2
fi
