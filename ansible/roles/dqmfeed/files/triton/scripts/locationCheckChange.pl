#!/usr/bin/perl

use Data::Dumper;
use LWP::UserAgent;
use JSON qw( decode_json encode_json );
use DBI;
use Config::Simple;

# enable/disable email
$path="/home/triton";

$cfg = new Config::Simple('/etc/vaisala-config/triton.ini');
$username=$cfg->param("triton.username");
$password=$cfg->param("triton.password");
$base_url=$cfg->param("triton.url");
$db=$cfg->param("triton.db");
$dbUser=$cfg->param("triton.dbUser");
$dbPass=$cfg->param("triton.dbPass");
$sendEmail=$cfg->param("smtp.enabled");
$smtpdestination=$cfg->param("smtp.destination");

$url=$base_url . "tritons/";

$ua = new LWP::UserAgent;
$req =  HTTP::Request->new( GET => "$url");
$req->authorization_basic( "$username", "$password" );
$response = $ua->request( $req );


$decodedContent = $response->decoded_content();

# print Dumper($decodedContent);
# exit;

$decodedJSON = decode_json( $decodedContent );

$longitude = $decodedJSON->{'stations'}[0]{'longitude'};
$latitude = $decodedJSON->{'stations'}[0]{'latitude'};
$elevation = $decodedJSON->{'stations'}[0]{'elevation'};

@array = @{$decodedJSON->{'stations'}};
$total=@array;

# print Dumper($decodedJSON);
# print "total is $total\n";
# exit;

for ($count=0;$count<$total;$count++) {
	$id=		$array[$count]{'id'};
	$longitude=	$array[$count]{'longitude'};
	$latitude=	$array[$count]{'latitude'};
	$elevation=	$array[$count]{'elevation'};

	$site{$id}{'longitude'}=	$longitude;
	$site{$id}{'latitude'}=		$latitude;
	$site{$id}{'elevation'}=	$elevation;

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

push (@locations, "$tritonName,$latitude,$longitude,$elevation");
	}

#### check / inserting changes ####

# connect
$dbh = DBI->connect("DBI:Pg:dbname=qualmon2;host=$db", "$dbUser", "$dbPass", {'RaiseError' => 1});

# check what the current lat/lon/elev values are
$sth = $dbh->prepare("select lat,lon,alt from qm.station_identity where xml_target_name='$site'");
	$sth->execute();


foreach $line (@locations) {
	unless ($line =~ m/^(T\d{5})\,([^\,]*)\,([^\,]*)\,([^\,]*)/) { next; }
		$site=$1;
		$lat=$2;
		$lon=$3;
		$alt=$4;
		chomp $alt;

# $lat = $lat + .05;

#	print "Site: $site, Lat: $lat, Lon: $lon, Alt: $alt\n";


# check what the current lat/lon/elev values are
	$sth = $dbh->prepare("select lat,lon,alt from qm.station_identity where xml_target_name='$site'");
	$sth->execute();
	while($ref = $sth->fetchrow_hashref()) {
		$dbLat= $ref->{'lat'};
		$dbLon= $ref->{'lon'};
		$dbAlt= $ref->{'alt'};
		}
	$sth->execute();

# if they've changed, update the table with the new values and email those concerned
	if (($dbLat != $lat) || ($dbLon != $lon) || ($dbAlt != $alt)) {
	  if ($sendEmail) {
             system("echo -e \"Old Lat: $dbLat\tNew Lat: $lat\nOld Lon: $dbLon\tNew Lon: $lon\nOld Alt: $dbAltz\tNew Alt: $alt \" | mailx -v -s \"Triton location change: $site\" -A triton $smtpdestination");
	     }
		print "Site $site changed!\nOld: $dbLat, $dbLon, $dbAlt\n";
		print "New: $lat, $lon, $alt\n\n";
		$sth = $dbh->prepare("update qm.station_identity set lat='$lat', lon='$lon', alt='$alt' where xml_target_name='$site'");
		$sth->execute();
		}
	}


$sth->finish();
$dbh->disconnect();
