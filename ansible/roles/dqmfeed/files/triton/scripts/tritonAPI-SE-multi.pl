#!/usr/bin/perl

use Data::Dumper;
use LWP::UserAgent;
use JSON qw( decode_json encode_json );
use Config::Simple;
use Time::Local;
use Time::HiRes qw(gettimeofday);

@twodigits=("00" .. "99");

($nowSecond, $nowMinute, $nowHour, $nowDay, $nowMonth, $nowYear, $nowWday, $nowYday, $nowIsdst) = localtime(time);

$nowYear+=1900;
$nowMonth+=1;

$nowMonth= $twodigits[$nowMonth];
$nowDay= $twodigits[$nowDay];
$nowHour= $twodigits[$nowHour];
$nowMinute= $twodigits[$nowMinute];

if ($nowMinute < 10) { $nowMinute="00"; }
if (($nowMinute >= 10) and ($nowMinute <20)) { $nowMinute="10"; }
if (($nowMinute >= 21) and ($nowMinute <30)) { $nowMinute="20"; }
if (($nowMinute >= 31) and ($nowMinute <40)) { $nowMinute="30"; }
if (($nowMinute >= 41) and ($nowMinute <50)) { $nowMinute="40"; }
if ($nowMinute >= 51) { $nowMinute="50"; }

$nowTimeStamp = "$nowYear-$nowMonth-${nowDay}T$nowHour:$nowMinute:00Z";


# read in the starting point Triton ID.  Will process 100 at a time, per call
$segment=$ARGV[0];
chomp $segment;
$segmentBegin=$segment;
$segmentEnd=$segment+99;

unless ($segment =~ m/\d/) { exit; }

$path="/home/triton";
# only need events 2,15,16,17,20


$cfg = new Config::Simple('/etc/vaisala-config/triton.ini');
$username=$cfg->param("triton.username");
$password=$cfg->param("triton.password");
$base_url=$cfg->param("triton.url");

$url = $base_url . "tritons/";

$ua = new LWP::UserAgent;
$req =  HTTP::Request->new( GET => "$url");
$req->authorization_basic( "$username", "$password" );
$response = $ua->request( $req );


$decodedContent = $response->decoded_content();

$decodedJSON = decode_json( $decodedContent );

# print Dumper($decodedJSON);
# exit;

@array = @{$decodedJSON->{'stations'}};
$total=@array;

for ($count=0;$count<$total;$count++) {
  $id=            $array[$count]{'id'};
  push (@stations, $id);
  }

foreach $station (@stations) {
unless (($station >= $segmentBegin) and ($station <=$segmentEnd)) { next; }

  $foundSmat=0;
  $foundSodar=0;
  $foundSysmon=0;
  $foundArchiver=0;
  $eventsSent=0;

  open (EVENTTIMES,"$path/lastEvents/$station.txt");
  $lastTimeStamp = <EVENTTIMES>;
  close EVENTTIMES;
  chomp $lastTimeStamp;

  $url=$base_url . "tritons/$station/events?start_time=$lastTimeStamp";

print "Going with $url \n";
  $ua = new LWP::UserAgent;
  $req =  HTTP::Request->new( GET => "$url");
  $req->authorization_basic( "$username", "$password" );
  $response = $ua->request( $req );

  $decodedContent = $response->decoded_content();
  $decodedJSON = decode_json( $decodedContent );

@array = @{$decodedJSON->{'events'}};
$total=@array;

if ($total == 0) {
	print "No events!  Skipping station $station.\n";
	next;
	}

for ($count=0;$count<$total;$count++) {
  $eventTimeStamp=$decodedJSON->{'events'}[$count]{'time'};


  push (@timeStamps, "$eventTimeStamp\n");
 
  $description_id=$decodedJSON->{'events'}[$count]{'description_id'};
  $data=$decodedJSON->{'events'}[$count]{'data'};

    if ($description_id == 2) {
       $timeStamp=$eventTimeStamp;
       if ($data =~ m/smat v/) {
		$foundSmat=1;
		}
       elsif ($data =~ m/sodar v/) {
		$foundSodar=1;
		}
       elsif ($data =~ m/sysmon/) {
		$foundSysmon=1;
		}
       elsif ($data =~ m/archiver v/) {
		$foundArchiver=1;
		}
       else { next; }

       }

# 2017-04-10 19:47:09,Solo,36,P,236522,P,243293,P,217502,P
    if ($description_id == 15) {
       $data =~ m/([^\,]*)\,([^\,]*)\,([^\,]*)\,(P|F),([^\,]*)/;
         $stTime=$1;
           $st1=$2;	# Solo or Row
           $st2=$3;	# device number
           $st3=$4;	# whether it's P or F
           $st4=$5+0;   # Value in khz

# FAIL is 1
           if ($st3 eq "P") {
             $pf=0;
            }
           elsif (($st3 eq "F") && (($st4 < 50000 || $st4 > 400000))) {
             $pf=1;
            }
           else {
             $pf="0";
            }
           if ($st1 eq "Solo") {
                open (SPEAKER_STAT,">$path/speakerStats/$station.solo.$st2");
                print SPEAKER_STAT $pf;
                close SPEAKER_STAT;
                }
           if ($st1 eq "Row") {
                open (ROW_STAT,">$path/rowStats/$station.row.$st2");
                print ROW_STAT $pf;
                close ROW_STAT;
                }
           if ($stTime =~ m/\d/) {
                $timeStamp=$stTime;
                $stTime="";
                }
        }

    if ($description_id == 16) {
       $data =~ m/[^\,]*\,([^l]*)l/;
       $efoyFuelStatus = $1;
       push (@xml, "<vai3:value code=\"TRITON_Efoy_Fuel_Status.0\">$efoyFuelStatus</vai3:value>\n");
       $timeStamp=$eventTimeStamp;
       &xmlify;
       }

    if ($description_id == 17) {
       $data =~ s/h//g;
       $efoyRuntime = $data;
       push (@xml, "<vai3:value code=\"TRITON_Efoy_Runtime.0\">$efoyRuntime</vai3:value>\n");
       $timeStamp=$eventTimeStamp;
       &xmlify;
       }

    if ($description_id == 20) {
       push (@xml, "<vai3:value code=\"TRITON_Efoy_Communication.0\">1</vai3:value>\n");
       $timeStamp=$eventTimeStamp;
       &xmlify;
       }
}

# push the #2 sysEvents
unless ($eventsSent) {
 push (@xml, "     <vai3:value code=\"TRITON_Smat_Restart.0\">$foundSmat</vai3:value>\n");
 push (@xml, "     <vai3:value code=\"TRITON_Sodar_App_Restart.0\">$foundSodar</vai3:value>\n");
 push (@xml, "     <vai3:value code=\"TRITON_Sysmon_Restart.0\">$foundSysmon</vai3:value>\n");
 push (@xml, "     <vai3:value code=\"TRITON_Archiver_Error.0\">$foundArchiver</vai3:value>\n");

 $timeStamp=$eventTimeStamp;

 unless ($timeStamp =~ m/\d/) {
   $timeStamp = $nowTimeStamp;
 }
 print "\nSysEvent 2 Timestamp for station $station:  $timeStamp\n";

 &xmlify;
 $eventsSent=1;
}

# find the last timestamp, and write that to file
@timeStamps=sort(@timeStamps);
$totalTimeStamps=@timeStamps;
$lastTimeStamp=$timeStamps[$totalTimeStamps-1];
open (EVENTTIMES,">$path/lastEvents/$station.txt");
print EVENTTIMES $lastTimeStamp;
close EVENTTIMES;
@timeStamps=();

# check to see if there were speaker updates for every speaker.  If not, go with the last known state.
for ($Speaker=1;$Speaker<=36;$Speaker++) {
    open (SPEAKER_STAT,"$path/speakerStats/$station.solo.$Speaker");
    $speakerStat=<SPEAKER_STAT>;
    close SPEAKER_STAT;
    if ($lastTimeStamp =~ m/\d/) {
      $timeStamp=$lastTimeStamp;
      }
    unless ($speakerStat =~ m/\d/) { $speakerStat=0; }	# if we have no record of it, assume it's 0/ok
    $speakerTotal[$station]=$speakerTotal[$station]+$speakerStat;	# add up all the speaker fails
}

# keep track of the speaker totals for that station in files
@xml=();
open (SPEAKER_TOTALS,">$path/speakerStats/$station.solo.total");
print SPEAKER_TOTALS $speakerTotal[$station];
close SPEAKER_TOTALS;
push (@xml, "<vai3:value code=\"TRITON_Speaker_Failures.0\">$speakerTotal[$station]</vai3:value>\n");
if ($timeStamp =~ m/\d/) {
 &xmlify('speaker');
 }
@xml=();

  
# check to see if there were row updates for every row.  If not, go with the last known state.
for ($Row=1;$Row<=7;$Row++) {
    open (ROW_STAT,"$path/rowStats/$station.row.$Row");
    $rowStat=<ROW_STAT>;
    close ROW_STAT;
    if ($lastTimeStamp =~ m/\d/) {
      $timeStamp=$lastTimeStamp;
      }
    unless ($rowStat =~ m/\d/) { $rowStat=0; }	# if we have no record of it, assume it's 0/ok
    $rowTotal[$station]=$rowTotal[$station]+$rowStat;	# add up all the row fails
}

# keep track of the row totals for that station in files
@xml=();
open (ROW_TOTALS,">$path/rowStats/$station.row.total");
print ROW_TOTALS $rowTotal[$station];
close ROW_TOTALS;
push (@xml, "<vai3:value code=\"TRITON_Row_Failures.0\">$rowTotal[$station]</vai3:value>\n");
if ($timeStamp =~ m/\d/) {
 &xmlify('row');
 }
@xml=();


# use the best timestamp if possible
unless ($timeStamp =~ m/\d/) {
  $timeStamp=$eventTimeStamp;
 }

# if that doesn't exist, use the lastTimeStamp
unless ($timeStamp =~ m/\d/) {
  $timeStamp=$lastTimeStamp;
}

# if that doesn't exist, punt
# unless ($timeStamp =~ m/\d/) { next; }


# checking rather than punt, use nowTimeStamp
unless ($timeStamp =~ m/\d/) {
  $timeStamp=$nowTimeStamp;
  $| = 1;
  print "Going with $nowTimeStamp for $station..\n";
}
 

if ((@xml) && ($eventsSent=0)) {
 &xmlify;
 }

}


sub xmlify {
  $optionData = $_[0];

if ($station < 100) {
  $tritonName = "T000" . $station;
}
elsif ($station < 1000) {
  $tritonName = "T00" . $station;
}
elsif ($station < 10000) {
  $tritonName = "T0" . $station;
}
else {
  $tritonName = "T" . $station;
}

# 15:	2017-04-12 19:41:36
# api:  2017-04-12T19:49:38.798Z
print "Original Timestamp is $timeStamp\n";

$timeStamp =~ m/(\d{4})\-(\d{2})\-(\d{2})\D(\d{2})\:(\d{2})/;
  $tsYear=        $1;
  $tsMonth=       $2;
  $tsDay=         $3;
  $tsHour=        $4;
  $tsMinute=      $5;

$tsUnixTime=    timelocal(0,$tsMinute,$tsHour,$tsDay,$tsMonth-1,$tsYear-1900);

$tsUnixTime= $tsUnixTime + 600;


($tsSecond, $tsMinute, $tsHour, $tsDay, $tsMonth, $tsYear, $tsWday, $tsYday, $tsIsdst) = localtime($tsUnixTime);

$tsYear+=1900;
$tsMonth+=1;

$tsMonth= $twodigits[$tsMonth];
$tsDay= $twodigits[$tsDay];
$tsHour= $twodigits[$tsHour];
$tsMinute= $twodigits[$tsMinute];

if ($tsMinute < 10) { $tsMinute="00"; }
if (($tsMinute >= 10) and ($tsMinute <20)) { $tsMinute="10"; }
if (($tsMinute >= 21) and ($tsMinute <30)) { $tsMinute="20"; }
if (($tsMinute >= 31) and ($tsMinute <40)) { $tsMinute="30"; }
if (($tsMinute >= 41) and ($tsMinute <50)) { $tsMinute="40"; }
if ($tsMinute >= 51) { $tsMinute="50"; }


$timeStamp = "$tsYear-$tsMonth-${tsDay}T$tsHour:$tsMinute:00Z";

print "New Timestamp is $timeStamp\n\n";

if ($optionData =~ m/speaker/) {
  $xmlDir = "speaker-xml";
  $xmlFile = "$tritonName-speaker.xml";
 }
elsif ($optionData =~ m/row/) {
  $xmlDir = "row-xml";
  $xmlFile = "$tritonName-row.xml";
 }
else {
  $xmlDir = "status-xml";
  $xmlFile = "$tritonName-$count.xml";
}

$fileTimeStamp = $timeStamp;
$fileTimeStamp =~ s/\:/\_/g;


print "Creating XML ${fileTimeStamp}_Event_${xmlFile}\n";
print "With XML:  @xml\n\n";

open (XML,">$path/$xmlDir/${fileTimeStamp}_Event_${xmlFile}");
$|=1;
print XML <<HEADER;
<?xml version="1.0" encoding="UTF-8"?>
<vai3:observation
xmlns:SOAP-ENV="http://schemas.xmlsoap.org/soap/envelope/"
xmlns:SOAP-ENC="http://schemas.xmlsoap.org/soap/encoding/"
xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
xmlns:xsd="http://www.w3.org/2001/XMLSchema"
xmlns:vai4="http://www.vaisala.com/schema/ice/iceMsgCommon/v1"
xmlns:vai1="http://www.vaisala.com/wsdl/ice/uploadIceObservation/v2"
xmlns:vai3="http://www.vaisala.com/schema/ice/obsMsg/v2"
version="2.0" fastTrackQC="false">
 <vai3:instance>
    <vai3:target>
      <vai4:idType>stationFullName</vai4:idType>
HEADER

print XML "     <vai4:id>$tritonName</vai4:id>\n";

print XML "    </vai3:target>\n";

print XML "    <vai3:resultOf codeSpace=\"NTCIP\" timestamp=\"$timeStamp\">\n";

print XML "@xml";

print XML <<FOOTER;
    </vai3:resultOf>
 </vai3:instance>
</vai3:observation>
FOOTER

close XML;
++$rowCount;
@xml=();
$timeStamp="";
}
