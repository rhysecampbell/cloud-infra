#!/usr/bin/perl

use Data::Dumper;
use LWP::UserAgent;
use JSON qw( decode_json encode_json );
use Config::Simple;

# read in the starting point Triton ID.  Will process 100 at a time, per call
$segment=$ARGV[0];
chomp $segment;
$segmentBegin=$segment;
$segmentEnd=$segment+99;

unless ($segment =~ m/\d/) { exit; }

$cfg = new Config::Simple('/etc/vaisala-config/triton.ini');
$username=$cfg->param("triton.username");
$password=$cfg->param("triton.password");
$base_url=$cfg->param("triton.url");
$path="/home/triton";

$url = $base_url . "tritons/";

open (FIELDS,"$path/fields-lookup.txt");
@fields=<FIELDS>;
close FIELDS;


foreach $line (@fields) {
	$line =~ m/([^\|]*)\|(\w*)/;
	$DQMfieldName = $1;
	$APIfieldName = $2;
	$field{$APIfieldName} = $DQMfieldName;
	}

$ua = new LWP::UserAgent;
$req =  HTTP::Request->new( GET => "$url");
$req->authorization_basic( "$username", "$password" );
$response = $ua->request( $req );


$decodedContent = $response->decoded_content();

# print Dumper($decodedContent);
# exit;

$decodedJSON = decode_json( $decodedContent );

# print Dumper($decodedJSON);
# exit;


@array = @{$decodedJSON->{'stations'}};
$total=@array;

for ($count=0;$count<$total;$count++) {
	$id=	$array[$count]{'id'};
	push (@ids, $id);
	}


foreach $id (@ids) {
unless (($id >= $segmentBegin) and ($id <=$segmentEnd)) { next; }
open (LASTUPDATES,"$path/lastUpdates/$id.update");
$lastUpdate=<LASTUPDATES>;
close LASTUPDATES;

$lastUpdate =~ s/00Z/01Z/g;


    $url=$base_url . "tritons/$id/observations?start_time=$lastUpdate";

print "Getting $url\n";

if ($id < 100) {
	$tritonName = "T000" . $id;
}
elsif ($id < 1000) {
	$tritonName = "T00" . $id;
}
elsif ($id < 10000) {
	$tritonName = "T0" . $id;
}
else {
	$tritonName = "T" . $id;
}

$ua = new LWP::UserAgent;
$req =  HTTP::Request->new( GET => "$url");
$req->authorization_basic( "$username", "$password" );
$response = $ua->request( $req );


$decodedContent = $response->decoded_content();
unless ($decodedContent =~ m/^\{/) {
	print "Skipping $id ($tritonName)- bogus JSON\n";
	next;
	}

$decodedJSON = decode_json( $decodedContent );


@timeArray = @{$decodedJSON->{'timestamps'}};
$totalTimes=@timeArray;


for ($timeCount=0;$timeCount<$totalTimes;$timeCount++) {

$timeStamp = $decodedJSON->{'timestamps'}[$timeCount];
print "Timestamp: $timeStamp\n";

unless ($timeStamp =~ m/\d/) {
	print "Skipping $id ($tritonName)- no timestamp\n";
	next;
	}

&XMLify;
}

## check for latest timestamp, and record to file

 $url=$base_url . "tritons/$id/observations";

$ua = new LWP::UserAgent;
$req =  HTTP::Request->new( GET => "$url");
$req->authorization_basic( "$username", "$password" );
$response = $ua->request( $req );

$decodedContent = $response->decoded_content();
$decodedJSON = decode_json( $decodedContent );

$latestTimeStamp = $decodedJSON->{'timestamps'}[0];

open (LASTUPDATES,">$path/lastUpdates/$id.update");
print LASTUPDATES $latestTimeStamp;
close LASTUPDATES;



}

sub XMLify {
$fileTime = $timeStamp;
$fileTime =~ s/\:/\_/g;

print "$tritonName\n";
open (XML,">$path/xml-processed/${fileTime}_${tritonName}_${timeCount}.xml");

print XML <<XML1;
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
      <vai4:id>$tritonName</vai4:id>
    </vai3:target>
<vai3:resultOf codeSpace="NTCIP" timestamp="$timeStamp" reason="scheduled">
XML1



# get the field names
%array1 = %{$decodedJSON->{'variables'}};
while( $key1 = each %array1 ){
  %array2 = %{$decodedJSON->{'variables'}{$key1}};
  while ($key2 = each %array2 ){
   $key1 =~ s/\s/\_/g;
   $key1 =~ s/\-/\_/g;

   $fullKeyValue = $key1 . "_" . $key2;

   if ($field{$fullKeyValue}) {
      $DQMfieldName = $field{$fullKeyValue};
   }
   else { next; }

   if ($DQMfieldName eq "Ambient_Temp.0") { $ambientTemp = $decodedJSON->{'variables'}{$key1}{$key2}[$timeCount]; };
   if ($DQMfieldName eq "Humidity.0") { $humidity = $decodedJSON->{'variables'}{$key1}{$key2}[$timeCount]; };
   if ($DQMfieldName eq "Barometric_Pressure.0") { $pressure = $decodedJSON->{'variables'}{$key1}{$key2}[$timeCount]; };
   if (($ambientTemp =~ m/\d/) && ($humidity =~ m/\d/) && ($pressure =~ m/\d/)) {
     &calcAlphaFreq($pressure,$ambientTemp,$humidity,4400);
     $ambientTemp="";
     $humidity="";
     $pressure="";
     print XML "     <vai3:value code=\"TRITON_Atmospheric_Absorption.0\">$alpha</vai3:value>\n";
     $alpha="";
     }

    print XML "     <vai3:value code=\"TRITON_$DQMfieldName\">$decodedJSON->{'variables'}{$key1}{$key2}[$timeCount]</vai3:value>\n"
   }
}


print XML <<XML3;
    </vai3:resultOf>
  </vai3:instance>
</vai3:observation>
XML3

close XML;
$ambientTemp="";
$humidity="";
$pressure="";
$alpha="";
}

# pass ps,tmp,rh,freq
sub calcAlphaFreq {
  $ps=@_[0];
  $tmp=@_[1];
  $rh=@_[2];
  $freq=@_[3];


  # Temperature ratio for Nitrogen resonance
  $tau = ($tmp + 273.15)/293.15;

  # Molar concentration of water vapor, h
  $c_sat = -6.8346 * (273.16 / ($tmp + 273.15))**1.261 + 4.6151;
  $rho_sat = 10**$c_sat;
  $rho_ref = $ps/1013.25;
  $h = $rh * $rho_sat/$rho_ref;

  # Resonance mode of N2 molecules
  $freq_N2 = $rho_ref * $tau**(-1/2) * (9 + 280 * $h * exp(-4.17 * ($tau**(-1/3) - 1)));

  # Absorption mode of N2 molecules
  $freq_O2 = $rho_ref * (24 + 40400 * $h * (0.02 + $h)/(0.391 + $h));

  # Calculate b1 and b2, for insertion in absorption equation
  $b1 = 0.1068 * exp(-3352/($tmp + 273.15)) / ($freq_N2 + ($freq)**2/$freq_N2);
  $b2 = 0.01275 * exp(-2239.1/($tmp + 273.15)) / ($freq_O2 + ($freq)**2/$freq_O2);

  # Formula for atmospheric absorption co-efficient from above variables.
  $alpha = (8.686 * ($freq)**2) * ($tau**0.5) * (1.84*10**-11 * ($rho_ref**-1) + ($tau**-3 * ($b1 + $b2)));
}


exit;

print "Deleting old files..\n";
$old=3; #old files are 7 days old
opendir(XML,"$path/sendcc-completed") || die "Can't open $dir/sendcc-completed : $!\n";
@xmlFiles = readdir(XML); 
close(XML);

foreach $file(@xmlFiles)
{
  $now = time;
  @stat = stat("$path/sendcc-completed/$file");
  if ($stat[9] < ($now - 86400 * $old))
    {
       unlink("$path/sendcc-completed/$file");
    }
}
print "Done\n\n";
