#!/usr/bin/perl

use Time::Local;

use File::Path qw(make_path);

$country=$ARGV[0];
chomp $country;

$workPath="/var/www/html/counts";

$metarPath="/home/ldm/var/data/surface/work/python/outputdir";


opendir (FILES, "$metarPath/");
@files= sort (readdir (FILES));
closedir FILES;

# get rid of . and ..
shift @files;
shift @files;

foreach $file (@files) {
	$file =~ m/M(\d{4})(\d{2})(\d{2})(\d{2})(\d{2})/;
	$filenameYear=$1*1;
	$filenameMonth=$2*1;
	$filenameDay=$3*1;
	$filenameHour=$4*1;
	$filenameMin=$5*1;

	$filenameTime = timelocal(0,$filenameMin,$filenameHour,$filenameDay,$filenameMonth-1,$filenameYear-1900);

	open (FILE,"$metarPath/$file");
	while (<FILE>) {
		if (m/^([METAR ]*|[SPECI ]*)(\S{4})\s*(\d{2})(\d{2})(\d{2})Z/) {
			$site=$2;
			$day=$3*1;
			$hour=$4*1;
			$min=$5*1;

			# bail if we get some bogus values
			if (($day > 31) || ($hour > 23) || ($min > 59)) { next; }


			$metarGuessTime = timelocal(0,$min,$hour,$day,$filenameMonth-1,$filenameYear-1900);

			# make time values 2 digits long again
			@twodigits = ("00" .. "99");
			$day=	$twodigits[$day];
			$hour=	$twodigits[$hour];
			$min=	$twodigits[$min];

			# make sure we don't build a file in the future, since all we have is Day and Month in the reading
			if ($metarGuessTime - $filenameTime > 1814400) {
				# calculate the month and the year from 35 days ago.  All we need is the month and year
				$fixedTime = $metarGuessTime - 3024000;
				($fixedSec, $fixedMin, $fixedHour, $fixedDay, $fixedMonth, $fixedYear, $fixedWday, $fixedYday, $fixedIsdst) = localtime($fixedTime);
				$month=$fixedMonth+1;   # fixed month
				$year=$fixedYear+1900;  # fixed year
				}
				else {
				$month=$filenameMonth;  # else the filename month
				$year=$filenameYear;    # .. and year
				}

			$month=	$twodigits[$month];


			make_path("$workPath/results/$country/$year/$month/$day");
			if ($site) {
				open (SITEDATA,">>$workPath/results/$country/$year/$month/$day/$site.dat");
				print SITEDATA  "$hour$min	$file\n";
				close SITEDATA;

				# open, and sort
				open (SITEDATA,"$workPath/results/$country/$year/$month/$day/$site.dat");
				@preSort=<SITEDATA>;
				close SITEDATA;
				undef %sort;
				@postSort = grep(!$sort{$_}++, @preSort);

				# write out sorted results
				open (SITEDATA,">$workPath/results/$country/$year/$month/$day/$site.dat");
				print SITEDATA  @postSort;
				close SITEDATA;

				}
			}
		}
	}
