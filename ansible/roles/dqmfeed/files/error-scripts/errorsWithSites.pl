#!/usr/bin/perl

use File::Path qw(make_path);

$scriptsPath='/opt/error-scripts';
$logPath='/var/log/simpleserver/';
$resultsDir='/var/www/html/error-scripts/errorLogs';
$resultsDir2='/var/www/html/error-scripts/errorsBySite';

$today=time;

$daysAgo=1;

# get yesterday's log name for DQM error pages
$yesterday=$today-86400*$daysAgo;

($sec, $min, $hour, $day, $mon, $year, $wday, $yday, $isdst) = localtime($yesterday);
$mon++;           # localtime returns month as 0-11 so add 1
$year += 1900;    # localtime returns year minus 1900 so add it back

@twodigits = ("00" .. "99"); 
$day = $twodigits[$day];
$mon = $twodigits[$mon]; 

$yesterdayLog="dqm_$year-$mon-$day.log";

$yesterdate = "$year$mon$day";
make_path("$resultsDir/$yesterdate");
make_path("$resultsDir2/$yesterdate");



# collect all the thread IDs
open (LOG,"$logPath/$yesterdayLog");
while (<LOG>) {

# get the thread for the current line
$_ =~ m/\s{3}\((\d*)\)\s/;
$lineThread=$1;

$threadVals{$lineThread}="Thread";
@threads= keys %threadVals;

}

close LOG;

# process each thread

foreach $thread (@threads) {

print "Working on thread:  $thread..\n";

open (LOG,"$logPath/$yesterdayLog");
while (<LOG>) {

# get the thread for the current line
$_ =~ m/\s{3}\((\d*)\)\s/;
$lineThread=$1;


# if we match with the right thread ... ##

## create new set, 
if (($_ =~ m/\($thread\) put_observation/) && (@thisSet == 0)) {
	push (@thisSet, $_);		#start a new set with this new 'begin' line
	next;
	}

# finish old set, start new set
if (($_ =~ m/\($thread\) put_observation/) && (@thisSet)) {



	if ($foundErrors) {
		foreach $line (@thisSet) {
			if ($line =~ m/Instance\(\d*\) \*\*([^\*]*)\*\*/) {
				$station=$1;
				}
#			if ($line =~ m/^ERROR:\s\s([^\"]*)/) {
			if ($line =~ m/^ERROR:/) {
				$error=$line;
				chomp $error;
				$error =~ s/ /_/g;
				$error =~ s/\./_/g;
				$error =~ s/\?/_/g;
				$error =~ s/\(/_/g;
				$error =~ s/\)/_/g;
				$error =~ s/\"/_/g;
				$error =~ s/\://g;
				open (ERRORS,">>$resultsDir2/$yesterdate/$error.log");
				print ERRORS "$station\n";
				close ERRORS;

				}
			}
		$station =~ s/ /_/g;		
		open (RESULTS,">>$resultsDir/$yesterdate/$station.log");
		print RESULTS "===================BEGIN============================\n"; 
		print RESULTS @thisSet;
		print RESULTS "====================END=============================\n\n"; 
		close RESULTS;

		}


	@thisSet=();
	push (@thisSet, $_);		#start a new set with this new 'begin' line
	$foundErrors=0;
	next;
	}


# push relavent stuff into the set
if ($_ =~ m/\s{3}\($thread\)\s/) {
	push (@thisSet, $_);
	}

# capture the ERRORs.  If there is no thread, and we have some data already, these errors/lines are relevant
if (($lineThread == "") && (@thisSet)) {
	push (@thisSet, $_);
	$foundErrors=1;
	}
}

close LOG;

}

# run the unique sort script
system("$scriptsPath/errorsWithSitesSort.sh $yesterdate");
