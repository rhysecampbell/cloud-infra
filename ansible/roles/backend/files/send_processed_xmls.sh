#!/bin/bash
##########################################################
# BJT May 2013                                           #
# wrapper script for spreading the files in a single     #
# landing directory (from simpleServer Quality output)   #
# and invoking multiple instances of sendcc.             # 
# Add extra instances as required                        #
# Note                                                   #
# SimpleServer is normally limited to 10 threads         #
##########################################################

FILES=*.xml
COUNT=0
TOTAL=0
DIR1="/home/data/sendcc/quality/one"
DIR2="/home/data/sendcc/quality/two"
DIR3="/home/data/sendcc/quality/three"
DIR4="/home/data/sendcc/quality/four"

function spread {
# mv is 'atomic' so no need to rename files when moving
for f in $FILES
  do
  #  echo "Processing $f file..."
    if [ $COUNT -eq 0 ]
      then
        COUNT=1
        mv $f $DIR1/
    elif [ $COUNT -eq 1 ]
      then
        COUNT=2
        mv $f $DIR2/
    elif [ $COUNT -eq 2 ]
      then
        COUNT=3
        mv $f $DIR3/
    elif [ $COUNT -eq 3 ]
      then
        COUNT=0
        mv $f $DIR4/
    fi

 #   echo $COUNT
    TOTAL=$(($TOTAL + 1))
  done

}

function process {

 # echo processing
  for cycle in one two three four
  do
    if ! pgrep -f "sendcc -c $cycle.conf" >/dev/null 2>&1
    then
      /usr/local/bin/sendcc -c $cycle.conf -b
    fi
  done
}

cd /home/data/sendcc/quality/output

# cp /home/data/sendcc/wsdl-xml-in/*.xml /home/data/test_dir

# call spread function 

spread

# process files
process

# echo $TOTAL

# startup sendcc instances if files exit
# if [ $TOTAL -gt 1 ]
#   then process
# fi

