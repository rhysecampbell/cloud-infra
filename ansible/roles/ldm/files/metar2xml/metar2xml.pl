#!/usr/bin/perl

use Geo::METAR;
use Time::Local;

$path="/home/ldm/var/data/surface/work";

open (CODES, "$path/ish.dat");
@codes=<CODES>;
close CODES;

opendir (DATADIR, "$path/carved");
@datadir= sort (readdir (DATADIR));
closedir DATADIR;

# get rid of . and ..
shift @datadir;
shift @datadir;

foreach $filename (@datadir) {
chomp $filename;

# get the date/time values from the filename
$filename =~ m/^M(\d\d\d\d)(\d\d)(\d\d)(\d\d)(\d\d)/;
$filenameYear=$1;
$filenameMonth=$2*1;
$filenameDay=$3*1;
$filenameHour=$4*1;
$filenameMin=$5*1;

$filename =~ m/(.*)\.MTR/;
$filebaseName=$1;


## Integrity Checks ##

# if file is empty, skip and go to next file
open (DATA, "$path/carved/$filename");
$check=<DATA>;
close DATA;
unless ($check =~ m/Z/) { next; }

open (DATA, "$path/carved/$filename");
open (XML, ">$path/xml/$filename.xml");

# print the header
print XML <<'END_HEADER';
<?xml version="1.0" encoding="UTF-8"?>
<vai3:observation xmlns:SOAP-ENV="http://schemas.xmlsoap.org/soap/envelope/" 
xmlns:SOAP-ENC="http://schemas.xmlsoap.org/soap/encoding/" 
xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" 
xmlns:xsd="http://www.w3.org/2001/XMLSchema" 
xmlns:vai4="http://www.vaisala.com/schema/ice/iceMsgCommon/v1" 
xmlns:vai1="http://www.vaisala.com/wsdl/ice/uploadIceObservation/v2" 
xmlns:vai3="http://www.vaisala.com/schema/ice/obsMsg/v2" fastTrackQC="false" version="2.0">

END_HEADER

# loop through each METAR in the file, extract the data, build XML
while (<DATA>) {

$metar=$_;
chomp $metar;

$m = new Geo::METAR;
$m->metar($metar);

$message=	$m->METAR;
$site=		$m->site;
$type=		$m->type;
$datatime=	$m->date_time;
$temperature=	1*$m->TEMP_C;
$dewpoint=	1*$m->DEW_C;
$windDir=	1*$m->WIND_DIR_DEG;
$windSpeed=	$m->WIND_MPH;
$windGust=	$m->WIND_GUST_MPH;
$visibility=	$m->visibility;
$altim=		$m->ALT;
$wxCodes=	$m->weather;
@wxCodes=	@{$m->{weather}};
@cloudCodes=	@{$m->{sky}};
$auto=		$m->AUTO_STATIONTYPE;

# if bad characters, skip and go to next line
if ($message =~ m/(\)|\(|\{|\}|\[|\]|\\|\?|\`|\")/) {
	if ($debugLevel) { print "Dropped METAR due to bad characters: $metar\n"; }
	next;
	}

unless ($type =~ m/METAR|SPECI/) { next; }

$metarTEMPC=	$m->TEMP_C;
$metarDEWC=	$m->DEW_C;

$temperature=	1*$metarTEMPC;
$dewpoint=	1*$metarDEWC;

# calculate the time/date info needed for the xml
&timestamp;

# convert MPH to M/S, 1 decimal
$windSpeed = sprintf "%.1f", $windSpeed * .44704;
$windGust = sprintf "%.1f", $windGust * .44704;


# If present, get the OVC and BKN values from @cloudCodes, needed for $flightCategory calc
@fcCloudCodes = grep { /OVC|BKN/ } @cloudCodes;

# Only interested in the numeric values of the Cloud Codes, so remove all non-digits in the array
for(@fcCloudCodes){s/\D//g};

# now determine smallest fcCloudCode value, and figure out the flightCategory
$minFccc = (sort { $a <=> $b } @fcCloudCodes)[0];
$minFccc = $minFccc * 100;

if ($minFccc < 500) { $flightCategory="LIFR"; }
if (($minFccc >= 500) && ($minFccc <= 999)) { $flightCategory="IFR"; }
if (($minFccc >= 1000) && ($minFccc <= 3000)) { $flightCategory="MVFR"; }
if ($minFccc > 3000) { $flightCategory="VFR"; }

# if we don't have any Cloud Codes
unless (@fcCloudCodes) { $flightCategory="VFR"; }

@fcCloudCodes=();

# altim to 2 decimal
$altim = sprintf "%.2f",$altim;


# get site airport name, lat, lon, elevation
foreach $code (@codes) {

if ($code =~ m/^$site\|/) {
	$siteInfo=$code;
        last;
        }
else {
        $siteInfo="";
        }
}

if ($siteInfo =~ m/[^\|]*\|([^\|]*)\|([^\|]*)\|([^\|]*)\|([^\|]*)/) {
        $airportName=$1;
        $latitude=sprintf("%.3f", $2);
        $longitude=sprintf("%.3f", $3);
        $elevation=$4;
        chomp $elevation;
        $location{$idFound}="$latitude,$longitude,$elevation";
}
else {
        $airportName="";
        $latitude="";
        $longitude="";
        $elevation="";
}


# Min/Max temp
if ("${message} " =~ m/ 4(\d)(\d{3})(\d)(\d{3}) /) {
	$maxTempPolarity=$1;
	$maxTemp=$2/10;
	$minTempPolarity=$3;
	$minTemp=$4/10;
	if ($1) { $maxTemp = $maxTemp * -1; }
	if ($3) { $minTemp = $minTemp * -1; }
}

# Precip in mm, 2 decimal
if ("${message} " =~ m/ 7(\d{4}) /) {
#	print "PRECIP is $1\n";
	$precipitation = sprintf "%.2f", $1/100*25.4;
}

# Get rid of Visibility Directional tags; we don't want/need them
$visibility =~ s/NDV$//g;	# get rid of NDV (No variation with Direction of Visibility tag)
$visibility =~ s/NW$//g;	# get rid of Direction tags
$visibility =~ s/NE$//g;	# get rid of Direction tags
$visibility =~ s/SW$//g;	# get rid of Direction tags
$visibility =~ s/SE$//g;	# get rid of Direction tags
$visibility =~ s/N$//g;		# get rid of Direction tags
$visibility =~ s/S$//g;		# get rid of Direction tags
$visibility =~ s/E$//g;		# get rid of Direction tags
$visibility =~ s/W$//g;		# get rid of Direction tags
$visibility =~ s/^P//g;		# get rid of "Is Equal Greater" tags


# if visibility is "M1/4SM" (less than 1/4SM), set it manually to something less than 1/4SM
if ($visibility eq "M1/4SM") { $visibility=402.01; }

# deal with the fraction values which might be in the visibility reading
# replacing any 'space' with '+', will permit the eval function to create a value
$visibility =~ s/ /\+/;

# If in Statute Miles, convert to Meters.  Otherwise, eval it and take it as it is
if ($visibility =~ m/(.*)(SM)/) {
	$visValue= eval $1;
	$visibility=$visValue * 1609.34;
	}

else {
	$visibility = eval $visibility;
	}

$visibility = 1* (sprintf "%.2f", $visibility);


# Get first character of $type:  M for METAR, S for SPECI
$typeCode= substr($type, 0, 1);

# Write out the XML
print XML "  <vai3:instance>\n";
print XML "    <vai3:target>\n";
print XML "      <vai4:idType>stationId</vai4:idType>\n";

print XML "      <vai4:id>$site</vai4:id>\n";

# don't write out if lat or lon are zero
unless ($longitude * $latitude == 0) {print XML "        <vai4:geoPosition x=\"$longitude\" y=\"$latitude\" z=\"$elevation\"></vai4:geoPosition>\n";}

print XML "    </vai3:target>\n";

print XML "    <vai3:resultOf reason=\"scheduled\" codeSpace=\"AIRPORTS\" timestamp=\"$XMLtimestamp\">\n";

print XML "      <vai3:value code=\"${typeCode}_rawMessage\">$message</vai3:value>\n";
print XML "      <vai3:value no=\"1\" code=\"${typeCode}_metarType\">$type</vai3:value>\n";

if ($windDir) { print XML "      <vai3:value no=\"1\" code=\"${typeCode}_windDirection\">$windDir</vai3:value>\n";}
if ($windSpeed) { print XML "      <vai3:value no=\"1\" code=\"${typeCode}_windSpeed\">$windSpeed</vai3:value>\n";}
if ($windGust>0) { print XML "      <vai3:value no=\"1\" code=\"${typeCode}_windGustSpeed\">$windGust</vai3:value>\n";}

if ($visibility) { print XML "      <vai3:value no=\"1\" code=\"${typeCode}_visibility\">$visibility</vai3:value>\n";}

foreach $cloudcode (@cloudCodes) {
	$cloudcodeCount++;
	print XML "      <vai3:value no=\"$cloudcodeCount\" code=\"${typeCode}_skyCondition\">$cloudcode</vai3:value>\n";
	}
	$cloudcodeCount=0;

foreach $wxcode (@wxCodes) {
	$wxcodeCount++;
	print XML "      <vai3:value no=\"$wxcodeCount\" code=\"${typeCode}_wxCode\">$wxcode</vai3:value>\n";
	}
	$wxcodeCount=0;

if ($metarTEMPC =~ m/\d/) { print XML "      <vai3:value no=\"1\" code=\"${typeCode}_airTemperature\">$temperature</vai3:value>\n";}
if ($metarDEWC =~ m/\d/) { print XML "      <vai3:value no=\"1\" code=\"${typeCode}_dewPoint\">$dewpoint</vai3:value>\n";}
if ($altim>0) { print XML "      <vai3:value no=\"1\" code=\"${typeCode}_A_altim\">$altim</vai3:value>\n";}
if ($auto) { print XML "      <vai3:value no=\"1\" code=\"${typeCode}_QC_autoStation\">A$auto</vai3:value>\n";}
if ($precipitation>0) { print XML "      <vai3:value no=\"1\" code=\"${typeCode}_precipitation24Hours\">$precipitation</vai3:value>\n";}
if ($maxTemp) { print XML "      <vai3:value no=\"1\" code=\"${typeCode}_maxTemperature\">$maxTemp</vai3:value>\n";}
if ($minTemp) { print XML "      <vai3:value no=\"1\" code=\"${typeCode}_minTemperature\">$minTemp</vai3:value>\n";}
if ($flightCategory) { print XML "      <vai3:value no=\"1\" code=\"${typeCode}_flightCategory\">$flightCategory</vai3:value>\n";}
print XML "    </vai3:resultOf>\n";
print XML "  </vai3:instance>\n";


# subroutine to figure out the dates needed for the XML
sub timestamp {
	$datatime =~ m/(\d\d)(\d\d)(\d\d)Z/;
		$day=$1;
		$hour=$2;
		$min=$3;

                # bail if we get some bogus values
		if (($day > 31) || ($hour > 23) || ($min > 59)) { return; }

		unless (($day =~ m/\d/) && ($hour =~ m/\d/) && ($min =~ m/\d/)) {
			print "INVALID day, hour, min.  Day = $day, Hour = $hour, Min = $min\n";
			return;
			}

		$filenameTime = timelocal(0,$filenameMin,$filenameHour,$filenameDay,$filenameMonth-1,$filenameYear-1900);
		$metarGuessTime = timelocal(0,$min,$hour,$day,$filenameMonth-1,$filenameYear-1900);

		# make time values 2 digits long
		@twodigits = ("00" .. "99");
		$day=   $twodigits[$day];
		$hour=  $twodigits[$hour];
		$min=   $twodigits[$min];

	# if the 'filename based' time is > 3 weeks in the future (1814400 seconds, wrong), get the month and year from 35 days ago (3024000 seconds, last month).

		if ($metarGuessTime - $filenameTime > 1814400) {
			# calculate the month and the year from 35 days ago.  All we need is the month and year
			$fixedTime = $metarGuessTime - 3024000;
			($fixedSec, $fixedMin, $fixedHour, $fixedDay, $fixedMonth, $fixedYear, $fixedWday, $fixedYday, $fixedIsdst) = localtime($fixedTime);
			$month=$fixedMonth+1;   # fixed month
			$year=$fixedYear+1900;  # fixed year
			open (FIXED,">>/tmp/fixdate.txt");
			print FIXED "guessTime: $metarGuessTime, filenameTime: $filenameTime, time: $year.$month.$day.$hour.$min, $rawMessage\n";
			close FIXED;
			}
		else {
			$month=$filenameMonth;  # else the filename month
			$year=$filenameYear;    # .. and year
			}

		$month= $twodigits[$month];

		$XMLtimestamp="${year}-${month}-${day}T${hour}:${min}:00Z";

}

# reset all variables, so nothing accidentally carries over

$metar="";
$message="";
$site="";
$type="";
$datatime="";
$temperature="";
$dewpoint="";
$windDir="";
$windSpeed="";
$windGust="";
$visibility="";
$altim="";
$wxCodes="";
@wxCodes="";
@cloudCodes="";
$auto="";

@fcCloudCodes=();
@cloudCodes=();

$minFccc="";
$flightCategory="";

$siteInfo="";
$airportName="";
$latitude="";
$longitude="";
$elevation="";
%location=();

$precipitation="";

$visValue="";
$visSM="";

$typeCode="";

$cloudcode="";
$cloudcodeCount="";

$wxcode="";
$wxcodeCount="";

$maxTemp="";
$minTemp="";
$minTempPolarity="";
$maxTempPolarity="";

}

print XML "</vai3:observation>\n";

close DATA;
close XML;

}
