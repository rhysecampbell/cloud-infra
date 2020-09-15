#!/bin/sh
#
# ## Plugin for Nagios to monitor how man files a directory contain
# ## Written by Bernd Mueller (http://www.lisega.de/)
# ##
# ## - 20070426 coded and tested for Linux
# ## - no jet published on NagiosExchange
#
#
# ## You are free to use this script under the terms of the Gnu Public License.
# ## No guarantee - use at your own risc.
#
#
# Usage: ./check_nomoffiles -d <path> -w <warn> -c <crit>
#
# ## Description:
#
# This plugin determines the number of files in a directory
# and compares it with the supplied thresholds.
#
# ## Output:
#
# The plugin prints the Count of Files in the directory followed by "ok" or
# either "warning" or "critical" if the corresponing threshold is reached.
#
# Exit Codes
# 0 OK       Directory Count of files checked and everything is ok
# 1 Warning  Directory Count of files above "warning" threshold
# 2 Critical Directory Count of files above "critical" threshold
# 3 Unknown  Invalid command line arguments or could not determine directory size
#
# Example: check_numoffiles -d . -w 1000 -c 1400
#
# 121 Files - ok         (exit code 0)
# 1234 Files - warning   (exit code 1)
# 1633 Files - critical  (exit code 2)


# Paths to commands used in this script.  These
# may have to be modified to match your system setup.

PATH=""

find="/usr/bin/find"
xargs="/usr/bin/xargs"
tail="/usr/bin/tail"
awk="/usr/bin/awk"
cut="/usr/bin/cut"
wc="/usr/bin/wc"

PROGNAME=`/bin/basename $0`
PROGPATH=`echo $0 | /bin/sed -e 's,[\\/][^\\/][^\\/]*$,,'`
REVISION="Revision 1.0"
AUTHOR="(c) 2007 Bernd Mueller (http://www.lisega.de/)"

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
    echo "Directory Files monitor plugin for Nagios"
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

# Grab the command line arguments

thresh_warn=""
thresh_crit=""
exitstatus=$STATE_WARNING #default

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

##### Get size of specified directory

error=""
statresult=`$find $dirpath -maxdepth 1 -name "*.$extension" -type f | $wc -l |$tail -1`
dirsize=`echo $statresult`
result="ok"
exitstatus=$STATE_OK

##### Compare with thresholds

if [ "$thresh_warn" != "" ]; then
    if [ $dirsize -ge $thresh_warn ]; then
        result="warning"
        exitstatus=$STATE_WARNING
    fi
fi
if [ "$thresh_crit" != "" ]; then
    if [ $dirsize -ge $thresh_crit ]; then
        result="critical"
        exitstatus=$STATE_CRITICAL
    fi
fi

echo "NUMOFFILES: $dirsize - $result|numoffiles=$dirsize"
exit $exitstatus
