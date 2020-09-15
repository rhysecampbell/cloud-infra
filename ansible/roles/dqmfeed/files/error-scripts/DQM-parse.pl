#!/usr/bin/perl

use File::Path qw(make_path);

$path="/var/log/simpleserver/";
$resultsDir="/var/www/html/error-scripts/results";


# get today's log name for log.io
$today=time;

($sec, $min, $hour, $day, $mon, $year, $wday, $yday, $isdst) = localtime($today);
$mon++;           # localtime returns month as 0-11 so add 1
$year += 1900;    # localtime returns year minus 1900 so add it back

@twodigits = ("00" .. "99"); 
$day = $twodigits[$day];
$mon = $twodigits[$mon]; 

$todayLog="dqm_$year-$mon-$day.log";



# get yesterday's log name for DQM error pages
$yesterday=$today-86400;

($sec, $min, $hour, $day, $mon, $year, $wday, $yday, $isdst) = localtime($yesterday);
$mon++;           # localtime returns month as 0-11 so add 1
$year += 1900;    # localtime returns year minus 1900 so add it back

@twodigits = ("00" .. "99"); 
$day = $twodigits[$day];
$mon = $twodigits[$mon]; 

$yesterdayLog="dqm_$year-$mon-$day.log";


$count=0;

open (LOG,"$path/$yesterdayLog");
while (<LOG>) {
	chomp;
	if ($_ =~ m/^DETAIL.*\s(\d+)\)/) {
		$count++;
		$sensor=$1;
		$middleLine=$_;			#DETAIL
		$foundError=1;
		next;
		}
	$lastLine=$_;				#ERROR
	if ($foundError) {
		make_path("$resultsDir/${year}${mon}${day}/${sensor}");
		open (RESULT,">>$resultsDir/${year}${mon}${day}/$sensor/$count");
		print RESULT "$lastLine\n";
		print RESULT "$middleLine\n";
		print RESULT "$_\n\n";			#CONTEXT
		close RESULT;
		$foundError=0;
		}
}
