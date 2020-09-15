#!/usr/bin/perl

use CGI;
use Time::Local;


$logPath="/var/log/simpleserver/";

$| = 1;
$q = new CGI;
print $q->header(-type => 'text/html');

print "<head>\n";
print "<meta http-equiv=\"refresh\" content=\"2\">\n";
print "</head>\n";


$currentTime=time;

($sec, $min, $hour, $day, $mon, $year, $wday, $yday, $isdst) = localtime($currentTime);
$mon++;           # localtime returns month as 0-11 so add 1
$year += 1900;    # localtime returns year minus 1900 so add it back

@twodigits = ("00" .. "99"); 
$day = $twodigits[$day];
$mon = $twodigits[$mon]; 

$currentLogFile="dqm_$year-$mon-$day.log";



print "<b><font size=4> Current Log:  $currentLogFile</font></b>\n";
print "<pre>\n";
system("tail -40 $logPath/$currentLogFile");
print "</pre>\n";
print "<b><font size=4> END OF LOG </font></b>\n";
