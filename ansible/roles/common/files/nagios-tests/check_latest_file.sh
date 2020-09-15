#!/bin/bash

# Exit codes
STATE_OK=0
STATE_WARNING=1
STATE_CRITICAL=2
STATE_UNKNOWN=3
STATE_DEPENDENT=4

print_revision() {
    echo "$REVISION $AUTHOR"
}

print_usage() {
    echo "Usage: $PROGNAME -d <path> -e <extension> -w <warn> -c <crit>"
    echo "Usage: $PROGNAME --help"
    echo "Usage: $PROGNAME --version"
}

print_help() {
    print_revision $PROGNAME $REVISION
    echo ""
    echo "Plugin to find latest file & age for Nagios"
    echo ""
    print_usage
    echo ""
}

# Make sure the correct number of command line
# arguments have been supplied

if [ $# -lt 1 ]; then
    print_usage
    exit $STATE_UNKNOWN
fi

#defaults

thresh_warn=""
thresh_crit=""
exitstatus=$STATE_OK #default
result="OK"

# Grab the command line arguments
while getopts  "e:w:c:d:hv" flag
do
  case "$flag" in
        h)
            print_help
            exit $STATE_OK
            ;;
        v)
            print_revision $PROGNAME $VERSION
            exit $STATE_OK
            ;;
        d)
            dirpath=$OPTARG
            ;;
        e)
            extension=$OPTARG
            ;;
        w)
            thresh_warn=$OPTARG
            ;;
        c)
            thresh_crit=$OPTARG
            ;;
        *)
            echo "Unknown argument: $flag"
            print_usage
            exit $STATE_UNKNOWN
            ;;
  esac
done

string=$(find $dirpath -name *.${extension} -type f -printf '%C@ %p\n' 2>/dev/null| sort -n | tail -1)
if [[ $string == "" ]]
then
    echo "Nothing in $dirpath|latest=0s"
    exit $STATE_CRITICAL
fi
date=${string%%.*}
datenow=`date +%s`
diff=$(($datenow-$date))

if [ "$thresh_warn" == "NA" ] && [ "$thresh_crit" == "NA" ]
then
  thresh_warn=""
  thresh_crit=""
  exitstatus=$STATE_OK
  result="OK"
fi


##### Compare with thresholds
if [ "$thresh_crit" != "" ]
then
    if [ $diff -ge $thresh_crit ]
    then
        result="CRITICAL"
        exitstatus=$STATE_CRITICAL
    fi
elif [ "$thresh_warn" != "" ]
then
    if [ $diff -ge $thresh_warn ]
    then
        result="WARNING"
        exitstatus=$STATE_WARNING
    fi
fi
echo "Latest File $result - ${string##*/}|latest=${diff}s;${thresh_warn};${thresh_crit}"
exit $exitstatus
