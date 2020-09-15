#!/usr/bin/perl
# Author:  Ryan Wilcox
# Description: Backend componit of the admin website interface for the IPad app.

our ($swd,$progName,$slash,$basePath);
BEGIN {
	use Cwd 'abs_path'; # Find the full path even with system links
	($swd,$progName) = (abs_path($0) =~ /(.*)[\\|\/]([^\\|\/]*$)/);
	$slash = '/';
	$basePath = "$swd${slash}..";
	# Add these paths to the end of the search array. NOTE: use lib adds the beginning.
	$INC[++$#INC] = "$basePath${slash}lib"; # Perl libs/mods
}

use strict;
use Carp; # issue warnings from calling code.
use CGI::Simple; # Simple CGI interface libcgi-simple-perl
use CGI::Carp qw(fatalsToBrowser); # issue warnings from calling code.
use File::stat; # OO way for stat() functions
use DateTime; # easy to use time functions
use JSON; # libjson-perl
use Template; # libtemplate-perl
use POSIX qw(ceil floor strftime); # round up/down a given number and time formatting
use Digest::MD5 qw(md5_hex); # interface to the MD5 Algorithm
use Util; # Basic lib utilities
use Log; # Setup logging for used mods/libs
use DBpg; # PostgreSQL DB module

$CGI::Simple::POST_MAX = 8192;       # max upload via post default 100kB
$CGI::Simple::DISABLE_UPLOADS = 1;   # Disable uploads

my $logObj = Log->new('web'); # web= prints log message only to the log
my $logger = $logObj->setup; # Will setup logging for all higher level libs and modules used in this script

our $configFolder = "$basePath${slash}config${slash}"; # the location of the configs
our $env = &Util::readDynamicConfig("${configFolder}environment.cfg");
our $sql = &Util::readConfig("${configFolder}sqlCalls.cloudDB.cfg"); # Text file with the needed SQL calls
our $cgi = new CGI::Simple;
$cgi->parse_query_string;  # add $ENV{'QUERY_STRING'} data to our $q object

our %input;
for my $key ($cgi->param()) { # Convert all web form inputs into a hash and filter bad input
	my $value = join ',',$cgi->param($key); # Create comma list if given array data (even if data isn't an array)
	$value =~tr#[a-zA-Z0-9\ \t\n\.\,\/\\\;\:\[\]\{\}\(\)\!\@\#\^\&\<\>\=\-\_\'\|äöüÄÖÜß]# #c; # We only want these chars
	$value =~ s#(\.\.)##g; # Remove some other stuff that isn't needed, hackers! dir traversal
	$value =~ s#^\s+|\s+$##g; # Tailing and beginning spaces
	if($value eq "" || $value =~ /^\s*$/) { next; } # If the input's value is blank, then skip.
	$logger->trace("Input Data:  $key: '$value'"); # Log the data returned form user (debug is great!)
	$input{$key} = $value;
}

if(!defined($$env{templateDir})) {
	$logger->logcroak("Needed ENV variable doesn't exist 'templateDir'");
}
if(!defined($$env{imageURL})) {
	$logger->error("Needed environment variable not defined 'imageURL'");
}
if(!defined($$env{jsonURL})) {
	$logger->error("Needed environment variable not defined 'imageURL'");
}
###############################################################################################
our $db;


my %tableMap = (
	cloudList => {
		order => [qw(station_name xml_target_name lastupdated lat lon alt vregions region_id country_id image1_url)],
		map => {
			station_name => 'Station Name',
			xml_target_name => 'Station Alias Name <br />(XML name)',
			lastupdated => 'Last Received Data',
			lat => 'Latitude <br />(Decimal Degrees)',
			lon => 'Longitude <br />(Decimal Degrees)',
			alt => 'Altitude <br />(Meters)',
			vregions => 'Virtual Region',
			region_id => 'Organization Region Code <br />(from SM)',
			country_id => 'Country ID',
			image1_url => 'Image Filename <br />(from SM)',
		},
		sqlCall => 'stationIdentitySearch',
		sqlCallGroupBy => 'stationIdentitySearchGroupBy',
		sortKey => 'stn_id',
		useDB => 'cloud'
	},
	cloudAssociation => {
		order => [qw(station_name xml_target_name lastupdated region_id org_id country_id v_region_name addedby comments)],
		map => {
			station_name => 'Station Name',
			xml_target_name => 'Station Alias Name <br />(XML name)',
			lastupdated => 'Last Received Data',
			region_id => 'Organization Region Code <br />(from SM)',
			org_id => 'Organization Name <br />(from SM)',
			country_id => 'Country ID',
			v_region_name => 'Virtual Region',
			addedby => 'Station Added to Virtual Region By',
			comments => 'Comment'
		},
		sqlCall => 'viewVregionMap',
		sortKey => 'unique',
		useDB => 'cloud'
	},
	metarList => {
		order => [qw(station_name xml_target_name lastupdated lat lon alt vregions country_id)],
		map => {
			station_name => 'Station Name',
			xml_target_name => 'ICAO/XML Name',
			lastupdated => 'Last Received Data',
			lat => 'Latitude <br />(Decimal Degrees)',
			lon => ' Longitude <br />(Decimal Degrees)',
			alt => 'Altitude <br />(Meters)',
			vregions => 'Virtual Region',
			country_id => 'Country ID',
		},
		sqlCall => 'stationIdentitySearch',
		sqlCallGroupBy => 'stationIdentitySearchGroupBy',
		sortKey => 'stn_id',
		useDB => 'metar'
	},
	metarAssociation => {
		order => [qw(station_name xml_target_name lastupdated country_id v_region_name addedby comments)],
		map => {
			station_name => 'Station Name',
			xml_target_name => 'ICAO/XML Name',
			lastupdated => 'Last Received Data',
			country_id => 'Country ID',
			v_region_name => 'Virtual Region',
			addedby => 'Station Added to Virtual Region By',
			comments => 'Comment'
		},
		sqlCall => 'viewVregionMap',
		sortKey => 'unique',
		useDB => 'metar'
	},
	roleList => {
		order => [ qw(role user_count role_description country_code  metar_data ltg_data graph_data registered ticker added_by) ],
		map => {
			role => 'Virtual Region',
			user_count => 'Assigned User Count',
			role_description => 'Region Display Name',
			country_code => 'Country Code',
			metar_data => 'METAR Enabled',
			ltg_data => 'Lighting Enabled',
			graph_data => 'Graph Enabled',
			registered => 'Region Enabled',
			ticker => 'Ticker Enabled',
			added_by => 'Added By',
		},
		sqlCall => 'authListRolesTable',
		sqlCallGroupBy => 'authListRolesTableGroupBy',
		sortKey => 'id',
		useDB => 'auth'
	},
	userList => {
		order => [ qw(username roles added_by comments date_added) ],
		map => {
			username => 'Username',
			roles => 'Virtual Regions',
			added_by => 'Account Added By',
			comments => 'Account Comments',
			date_added => 'Date Added'
		},
		sqlCall => 'userListTable',
		sqlCallGroupBy => 'userListTableGroupBy',
		sortKey => 'id',
		useDB => 'auth'
	}
);


my $json;
if(defined($input{rest})) { # This query will come from apache rewrite. /rest/
	my @cmd = split(/\//,$input{rest}); # strong will be organized with folders
	$logger->info("#@cmd#");
	
	foreach my $var (@cmd) { # if for any reason the user types help in the options we will point them to some help
		if($var eq 'help') {
			&help
		}
	}
	
	my $version = shift(@cmd);
	if($version eq 'v1.0') { # the standard
		if($cmd[0] eq 'getSimple') { # This is a way to allow the Javascript to call the SQL template without having to create a Perl sub for each
			if($cmd[1] =~ /^user/i || $cmd[1] =~ /^role/i) {
				$db = &dbConnect('authDB');
			} elsif($cmd[1] =~ /^metar/i) {
				$db = &dbConnect('metarDB');
			} else {
				$db = &dbConnect;
			}
			$json = &simpleList($cmd[1]);
		} elsif($cmd[0] =~ /^get(.*)/) {
			my $type = $1;
			if($type eq 'Metar') {
				$db = &dbConnect('metarDB');
			} else {
				$db = &dbConnect;
			}
			my $query;
			if(defined($cmd[2])) {
				$query = $cmd[2];
			} elsif(defined($input{q})) {
				$query = $input{q};
			}
			$query =~ s/([\%_])/\\$1/g; # So we don't want invoke postgres pattern matching, arg
			
			if($cmd[1] eq 'shortList') {
				$json = &createTableDataShort();
			}elsif($cmd[1] eq 'list') {
				$json = &createTableData($type,$input{stationID},$input{stationName},$input{xmlName},$input{regionID});
			}elsif($cmd[1] eq 'listStationMap') {
				$json = &createTableData2('stationMap',$input{stationID},$input{xmlID},$input{regionID});
			}elsif($cmd[1] eq 'listVirtualRegion') {
				$json = &createTableData2("${type}virtualRegionMap",$input{stationID},$input{xmlID},$input{regionID});
			}elsif($cmd[1] eq 'xmlName') {
				$json = &getXMLname($query);
			}elsif($cmd[1] eq 'stationName') {
				$json = &getStationName($query);
			}elsif($cmd[1] eq 'region') {
				$json = &getRegion($query);
			}elsif($cmd[1] eq 'vRegion') {
				$json = &getVregion($query);
			}elsif($cmd[1] eq 'orgRegion') {
				$json = &getOrgRegion($query);
			}elsif($cmd[1] eq 'organization') {
				$json = &getOrganization($query);
			} elsif($cmd[1] eq 'stationList') {
				$json = &getStationList($input{stationID},$input{xmlName},$input{regionID},$input{vRegion});
			}
			elsif($cmd[1] eq 'pagerTable') {
				# http://stackoverflow.com/questions/3241352/using-an-alias-column-in-the-where-clause-in-postgresql
				# $logger->trace("--------------------------------------------Type: $type");
				my $mapType = 'cloudAssociation';
				if (!defined($tableMap{$type})) {
					$json = {msg => "Error: Given type does not exist"};
				} else {
					$json = &createTableDataPager($tableMap{$type},[qw(size page @filter @column)]);
				}
			}
		} elsif($cmd[0] eq 'user') {
			$db = &dbConnect('authDB');
			if($cmd[1] eq 'list') {
				$json = &userList($cmd[2],'needComments');
			}elsif($cmd[1] eq 'listSimple') {
				$json = &userList($cmd[2]);
			} elsif($cmd[1] eq 'listRoles') {
				$json = &authListRoles($cmd[2]);
			} elsif($cmd[1] eq 'listRoles2') {
				$json = &authListRoles2();
			}elsif($cmd[1] eq 'add') {
				$json = &userAdd($input{username},$input{'roles[]'},$input{password},$input{addedBy},$input{description});
			}elsif($cmd[1] eq 'setRole') {
				$json = &userSetRole($input{username},$input{'roles[]'});
			}elsif($cmd[1] eq 'setPassword') {
				$json = &userPassword($input{username},$input{password});
			}elsif($cmd[1] eq 'delete') {
				$json = &userDelete($input{userID});
			}
		} elsif($cmd[0] eq 'role') {
			$db = &dbConnect('authDB');

			if($cmd[1] eq 'count') {
				$json = &getVirtualRegionCounts([qw(roleID)]);
			} elsif($cmd[1] eq 'setProperties') {
				$json = &setRoleProperties([qw(roleID regionID roleName roleDescription metarData ltgData graphData tickerData)]);
			}elsif($cmd[1] eq 'add') {
				# Be careful using this part of the code. This is not using foreign data wrapper to create a transaction on 3 databases
				# It is an ASSUMPTION that there will not be any one off regions in one database
				$json = &roleAdd([qw(role addedBy countryCode description metarData ltgData graphData tickerData)]); # only authDB

				if($$json{msg} =~ /^success/i) { # Only if the add worked on the auth DB should be continue
					$json = &addVirtualRegion([qw(role addedBy)]); # Cloud and Metar DBs
				}
			}elsif($cmd[1] eq 'delete') {
				$json = &roleDelete([qw(roleID)]);
			}elsif($cmd[1] eq 'deleteAll') {
				$json = &regionDeleteAll([qw(roleID)]);
			}
			# elsif($cmd[1] eq 'rename') {
			# 	$json = &regionRename([qw(regionID newName newDescription)]);
			# }
		} elsif($cmd[0] eq 'set') {
			if($cmd[1] =~ /^metar/i) {
				$db = &dbConnect('metarDB');
			} else {
				$db = &dbConnect;
			}
			
			if($cmd[1] =~ /virtualRegionMap$/) {
				$json = &setVirtualRegionMap($input{'stationList[]'},$input{vRegionList},$input{addedBy},$input{description});
			}
		} elsif($cmd[0] eq 'delete') {
			if($cmd[1] =~ /^metar/i) {
				$db = &dbConnect('metarDB');
			} else {
				$db = &dbConnect;
			}

			if($cmd[1] =~ /virtualRegionMap$/) {
				$json = &deleteVirtualRegionMap($input{'stationList[]'},$input{vRegion},$input{addedBy},$input{description});
			}
		} elsif($cmd[0] eq 'edit') {
			$json = &editData([qw(value id database)]);
		} else {
			&help;
		}
		
		if(!defined($json)) { # Just give blank output if nothing is found
			$logger->info("No JSON data created. Returning '{}'");
			print "Content-Type: application/json; charset=utf-8\n\n";
			print "{}\n";
			exit;
		}		
	} else {
		&help;
	}
}

if(!defined($json)) {
	print "Content-Type: text/html; charset=utf-8\n\n";
	print "Error: json was not defined\n";
} else {
	my $json_text = to_json($json);
	print "Content-Type: application/json; charset=utf-8\n\n";
	print $json_text ."\n";
}

###############################################################################################
sub editData {
	my ($varList) = @_;
	$logger->trace("Given ($varList)");

	my ($status,%var) = &getInputs($varList,'blankOK');
	if($status =~ /error/i) {
		return {msg => $status};
	}

	if(!defined($var{database})) {
		$logger->error("Not given a database");
		return;
	}
	if(!defined($var{id})) {
		$logger->error("Not given a ID");
		return;
	}
	# General checking for bad data and that the value was even given
	if($var{value} !~ /^[a-zA-Z0-9\s\.\,\(\)\[\]\{\}\|\?\/\!\@\#\$\%\^\&\*\;\:\"\'\<\>\-\_äöüÄÖÜß]+$/) {
		if($var{value} ne '') {
			my $msg = "Not given a good value '$var{value}'";
			$logger->error($msg);
			return {msg => $msg};
		}
	}

	if($var{value} eq 'blank') { # This is the method the frontend has for a select box for a blank value
		$var{value} = '';
	}

	my $insertValue = $var{value};

	my ($rowID, $variable) = ($var{id} =~ /(\d{1,9999})\-(\w{1,99})/);
	if(!defined($rowID) || !defined($variable)) {
		$logger->error("Given a value does not match the needed pattern ($var{id})");
		return;
	}

	my $dbHandle;
	if($var{database} eq 'cloud') {
		$dbHandle = &dbConnect;
	} else {
		$dbHandle = &dbConnect('metarDB');
	}

	# before we change anything lets make sure the data that we are given is even one we can work with
	my $returnedID = ($dbHandle->sqlKey($$sql{selectID},undef,[$rowID]))[0][0][0];
	if($returnedID != $rowID) {
		my $msg = "Given row ID ($rowID) not found in the database";
		$logger->warn($msg);
		return {msg => $msg};
	}

	# FIX add check to make sure variable exist in the DB before trying to change it (metar/cloud)
	my $allowedVariables = qw(station_name lat lon alt region_id image1_url image2_url forecast_url country_id org_id);

	# Per the verbal requirements the full URL path is not showed in the web page tables.
	# As a result those paths needed to be added again when the user edits the table URLS
	if($variable eq 'image1_url') {
		if($var{value} =~ /^http/) { # If the user gives a full path
			$insertValue = $var{value};
			if($var{value} =~ /^$$env{imageURL}/) { # If the full path is one we are using return just the short name
				my $file = ($var{value} =~ /([^\/]*$)/)[0];
				$var{value} = $file;
			}
		} else {
			$insertValue = "$$env{imageURL}\/$var{value}";
		}
	}
	if($variable eq 'forecast_url') {
		if($var{value} =~ /^http/) {
			$insertValue = $var{value};
			if($var{value} =~ /^$$env{jsonURL}/) { # If the full path is one we are using return just the short name
				my $file = ($var{value} =~ /([^\/]*$)/)[0];
				$var{value} = $file;
			}
		} else {
			$insertValue = "$$env{jsonURL}\/$var{value}";
		}
	}

	my $sqlcmd = $$sql{updateData};
	$sqlcmd .= " $variable=? WHERE stn_id=?";

	my $dataRef = $dbHandle->sqlKey($sqlcmd,undef,[$insertValue,$rowID]);

	return {value => $var{value}};
}

sub addVirtualRegion {
	my ($varList) = @_;
	$logger->trace("Given ($varList)");

	my ($status,%var) = &getInputs($varList);
	if($status =~ /error/i) {
		return {msg => $status};
	}

	my $dbMetar = &dbConnect('metarDB');
	my $dbCloud = &dbConnect;

	my $count = $dbMetar->sqlKey($$sql{selectvRegionName},undef,[$var{role}]);
	if(defined($$count[0][0])) {
			my $msg = "Warning: Role already exist in the MetarDB '$var{role}'";
			$logger->error($msg);
			return {msg => $msg};
	}
	my $count2 = $dbCloud->sqlKey($$sql{selectvRegionName},undef,[$var{role}]);
	if(defined($$count2[0][0])) {
			my $msg = "Warning: Role already exist in the CloudDB '$var{role}'";
			$logger->error($msg);
			return {msg => $msg};
	}

	# Need (role addedBy)
	my $lastID  = $dbMetar->sqlKey($$sql{addvRegion},undef,[$var{role},$var{addedBy}]);
	if($lastID !~ /^\d+$/) {
		my $msg = "Error: Could not get last inserted roles's ID";
		$logger->error($msg);
		return {msg => $msg};
	}

	my $lastID2  = $dbCloud->sqlKey($$sql{addvRegion},undef,[$var{role},$var{addedBy}]);
	if($lastID2 !~ /^\d+$/) {
		my $msg = "Error: Could not get last inserted roles's ID";
		$logger->error($msg);
		return {msg => $msg};
	}
	
	my $msg = "Success: Added role '$var{role}'";
	return {msg => $msg};
}

sub getVirtualRegionCounts {
	my ($varList) = @_;
	$logger->trace("Given ($varList)");
	my ($status,%var) = &getInputs($varList);
	if($status =~ /error/i) {
		return {msg => $status};
	}

	if(!defined($var{roleID})) {
		$logger->error("Not given a roleID");
		return;
	}

	my $dbAuth = &dbConnect('authDB');
	my $dbMetar = &dbConnect('metarDB');
	my $dbCloud = &dbConnect;

	my $roleName = ($dbAuth->sqlKey($$sql{selectRoleNameRef},undef,[$var{roleID}]))[0][0][0];

	my $authCount = ($dbAuth->sqlKey($$sql{selectRoleCountRef},undef,[$var{roleID}]))[0][0][0];
	my $metarCount = ($dbMetar->sqlKey($$sql{selectvRegionCount},undef,[$roleName]))[0][0][0];
	my $cloudCount = ($dbCloud->sqlKey($$sql{selectvRegionCount},undef,[$roleName]))[0][0][0];

	return {auth=> $authCount, cloud=> $cloudCount, metar=>$metarCount};
}

sub userAdd { # insert new user and do some base checking for invalid data from the web
	my ($username,$roles,$password,$addedBy,$description) = @_;
	# $logger->trace("Given ($username,$roles,$password,$addedBy,$description)");

	
	if(!defined($username)) {
		$logger->error("Not given a username");
		return;
	}
	if(!defined($password)) {
		$logger->error("Not given a password");
		return;
	}
	if(!defined($addedBy)) {
		$logger->error("Not given a addedBy");
		return;
	}
	if(!defined($description)) {
		$logger->error("Not given a description");
		return;
	}

	my $count = $db->sqlKey($$sql{authSelectUser},undef,[$username]);
	if(defined($$count[0][0])) {
		my $msg = "Warning: username is already defined '$username'";
		$logger->error($msg);
		return {msg => $msg};
	}

	my $digest = md5_hex($password); # Super simple hash for tomcat, should be salted and sha256 or better :(
	my $lastID  = $db->sqlKey($$sql{userAdd},undef,[$username,$digest,$addedBy,$description]);
	
	if($lastID !~ /^\d+$/) {
		my $msg = "Error: Could not get last inserted username's ID";
		$logger->error($msg);
		return {msg => $msg};
	}
	
	foreach my $roleID (split(/\,/, $roles)) {
		$logger->trace("Adding user to role: [$lastID,$roleID] for user $username");
		my $dataRef = $db->sqlKey($$sql{userAddRef},undef,[$lastID,$roleID]);
	}

	my $msg = "Success: Added user '$username'";
	return {msg => $msg};
}

sub userSetRole {
	my ($userID,$roles) = @_;

	if(!defined($userID)) {
		$logger->error("Not given a userID");
		return;
	}

	my %givenRoles; # create a lookup list of the given roles from the user
	
	## Create role if not all ready added from given list
	foreach my $roleID (split(/\,/, $roles)) { 
		$givenRoles{$roleID} = 1;

		my $dataRef = $db->sqlKey($$sql{userSelectRef},undef,[$userID,$roleID]);
		my $refID = $$dataRef[0][0];
		
		if(!defined($refID)) { # if the db doesn't already have that REF the create it
			$logger->trace("Adding user to role: [$userID,$roleID]");
			my $dataRef = $db->sqlKey($$sql{userAddRef},undef,[$userID,$roleID]);
		}
	
	}
	
	## Delete role if not given in the list
	my $userRef = $db->sqlKey($$sql{userGivenRoles},'id',[$userID]);
	foreach my $id (keys %{$userRef}) {
		$logger->trace("#$id#");
		if($givenRoles{$id} != 1) { # The given roles list is missing the one found in the DB. We now just need to delete that role
			# $logger->trace("#HERE#$$userRef{$id}{ref_id}#");
			$logger->trace("Deleting user role: [$userID,$$userRef{$id}{ref_id}]");
			my $dataRef = $db->sqlKey($$sql{useDeleteRef},undef,[$$userRef{$id}{ref_id}]);
		}
	}

	my $msg = "Success: changed user's role";
	return {msg => $msg};
}

sub roleAdd { # insert new role and do some base checking for invalid data from the web
	my ($varList) = @_;
	$logger->trace("Given ($varList)");

	my ($status,%var) = &getInputs($varList);
	if($status =~ /error/i) {
		return {msg => $status};
	}

	my $count = $db->sqlKey($$sql{authSelectRole},undef,[$var{role}]);
	if(defined($$count[0][0])) {
			my $msg = "Warning: Role already exist '$var{role}'";
			$logger->error($msg);
			return {msg => $msg};
	}

	# need: (role,added_by,role_description,metar_data,ltg_data,graph_data,ticker,country_code)
	my $lastID  = $db->sqlKey($$sql{authAddRole},undef,[$var{role},$var{addedBy},$var{description},$var{metarData},$var{ltgData},$var{graphData},$var{tickerData},$var{countryCode}]);
	
	if($lastID !~ /^\d+$/) {
		my $msg = "Error: Could not get last inserted roles's ID";
		$logger->error($msg);
		return {msg => $msg};
	}

	my $msg = "Success: Added role '$var{role}'";
	return {msg => $msg};
}

sub roleDelete { # This will only delete the role from the auth table
	my ($varList) = @_;
	$logger->trace("Given ($varList)");
	my ($status,%var) = &getInputs($varList);
	if($status =~ /error/i) {
		return {msg => $status};
	}

	my $id = $db->sqlKey($$sql{authSelectRoleID},undef,[$var{roleID}]);
	# use Data::Dumper;
	# my $test = Dumper(\$id);
	# $logger->trace("TEST#$test#");

	if(!defined($$id[0][0])) {
			my $msg = "Error: Role with that ID does not exist '$var{roleID}'";
			$logger->error($msg);
			return {msg => $msg};
	}

	# FIX: This should be put into a transaction:
	my $dataRef  = $db->sqlKey($$sql{authDeleteRoleRef},undef,[$var{roleID}]);
	my $dataRef2  = $db->sqlKey($$sql{authDeleteRole},undef,[$var{roleID}]);

	my $msg = "Success: deleted role '$var{roleID}'";
	return {msg => $msg};
}
sub regionDeleteAll {
	my ($varList) = @_;
	$logger->trace("Given ($varList)");
	my ($status,%var) = &getInputs($varList);
	if($status =~ /error/i) {
		return {msg => $status};
	}

	my $dbAuth = &dbConnect('authDB');
	my $dbMetar = &dbConnect('metarDB');
	my $dbCloud = &dbConnect;

	my $roleName = ($dbAuth->sqlKey($$sql{selectRoleNameRef},undef,[$var{roleID}]))[0][0][0];
	my $authCount = ($dbAuth->sqlKey($$sql{selectRoleCountRef},undef,[$var{roleID}]))[0][0][0];
	my $metarCount = ($dbMetar->sqlKey($$sql{selectvRegionCount},undef,[$roleName]))[0][0][0];
	my $cloudCount = ($dbCloud->sqlKey($$sql{selectvRegionCount},undef,[$roleName]))[0][0][0];
	my $cloudRoleID = ($dbCloud->sqlKey($$sql{selectvRegionID},undef,[$roleName]))[0][0][0];
	my $metarRoleID = ($dbMetar->sqlKey($$sql{selectvRegionID},undef,[$roleName]))[0][0][0];
	$logger->debug("Counts ($authCount,$metarCount,$cloudCount) name: '$roleName'  auth id: $var{roleID}  cloud id:$cloudRoleID  metar id:$metarRoleID");


	if($authCount >= 1) {
		my $dataRef  = $dbAuth->sqlKey($$sql{authDeleteRoleRef},undef,[$var{roleID}]);
	}
	my $dataRef2  = $dbAuth->sqlKey($$sql{authDeleteRole},undef,[$var{roleID}]);
	
	if(defined($metarRoleID)) {
		if($metarCount >= 1) {
			my $dataRef  = $dbMetar->sqlKey($$sql{deleteVregionRef},undef,[$metarRoleID]);
		}
		my $dataRef  = $dbMetar->sqlKey($$sql{deleteVregion},undef,[$metarRoleID]);
	}

	if(defined($cloudRoleID)) {
		if($cloudCount >= 1) {
			my $dataRef  = $dbCloud->sqlKey($$sql{deleteVregionRef},undef,[$cloudRoleID]);
		}
		my $dataRef  = $dbCloud->sqlKey($$sql{deleteVregion},undef,[$cloudRoleID]);
	}

	my $msg = "Success: deleted role '$var{roleID}'";
	return {msg => $msg};
}

sub regionRename { # This will rename a given role/region
	my ($varList) = @_;
	$logger->trace("Given ($varList)");
	my ($status,%var) = &getInputs($varList);
	if($status =~ /error/i) {
		return {msg => $status};
	}
	# regionID newName newDescription
	if(!defined($var{regionID})) {
		$logger->error("Not given regionID");
		return;
	}
	if(!defined($var{newName})) {
		$logger->error("Not given newName");
		return;
	}
	if(!defined($var{newDescription})) {
		$logger->error("Not given newDescription");
		return;
	}

	my $dbAuth = &dbConnect('authDB');
	my $dbMetar = &dbConnect('metarDB');
	my $dbCloud = &dbConnect;

	my $roleName = ($dbAuth->sqlKey($$sql{selectRoleNameRef},undef,[$var{regionID}]))[0][0][0];
	my $cloudRoleID = ($dbCloud->sqlKey($$sql{selectvRegionID},undef,[$roleName]))[0][0][0];
	my $metarRoleID = ($dbMetar->sqlKey($$sql{selectvRegionID},undef,[$roleName]))[0][0][0];
	$logger->debug("name: '$roleName'  auth id: $var{regionID}  cloud id:$cloudRoleID  metar id:$metarRoleID");

	my $msg = 'warning: Unknow error: Please contact admin with the current time of the error.';	
	if($roleName eq $var{newName}) { # This means we are just changing the Display name (newDescription)
		my $dbAuth   = $dbAuth->sqlKey($$sql{renameRole},undef,[$var{newName},$var{newDescription},$var{regionID}]);
		$msg = 'Success: Changed the Display Name (Region Description)';
	}elsif(defined($cloudRoleID) && defined($metarRoleID) && defined($roleName)) {
		$msg = "Success: Renamed region with the Auth ID of'$var{regionID}'";

		my $alreadyExistAuth  = ($dbAuth->sqlKey($$sql{authSelectRole},undef,[$var{newName}]))[0][0][0];
		my $alreadyExistCloud = ($dbCloud->sqlKey($$sql{selectvRegionName},undef,[$var{newName}]))[0][0][0];
		my $alreadyExistMetar = ($dbMetar->sqlKey($$sql{selectvRegionName},undef,[$var{newName}]))[0][0][0];
		$logger->debug("Already exist check ($alreadyExistAuth|$alreadyExistCloud|$alreadyExistMetar)");

		if(!defined($alreadyExistAuth) && !defined($alreadyExistCloud) && !defined($alreadyExistMetar)) {
			my $dbAuth   = $dbAuth->sqlKey($$sql{renameRole},undef,[$var{newName},$var{newDescription},$var{regionID}]);
			my $dataRef  = $dbCloud->sqlKey($$sql{renameVregion},undef,[$var{newName},$cloudRoleID]);
			my $dataRef  = $dbMetar->sqlKey($$sql{renameVregion},undef,[$var{newName},$metarRoleID]);
		} else {
			$msg = "warning: The selected new name already exist!";
		}
	} else {
		$msg = "warning: Problem selecting the needed data to rename the region";
	}

	
	return {msg => $msg};
}

sub getInputs { # make sure all needed variable are defined and return a simple hash
	my ($varList,$type) = @_;
	$logger->trace("Given ($varList,$type)");
	my $status = "";

	my %createdVars;
	foreach my $var (@{$varList}) {
		$logger->trace("var ($var) ($input{$var})");
		if($var =~ /^@(.*)/) { # Special variables that enables tablesorter pager 
			my $searchVar = $1;
			foreach my $key (keys %input) {
				if($key =~ /^$searchVar/) {
					my $position = ($key =~ /\[(\d+)\]/)[0];
					$createdVars{$searchVar}[$position] = $input{$key};
				}
			}
		} else {
			if($type eq 'blankOK') {
				; # Remove the check and just create the mapping
			} else {
		 		if(!defined($input{$var}) || $input{$var} eq '') {
					my $msg = "Error: Not defined variable '$var'";
					$logger->error($msg);
					return ($msg,undef);
				}
			}
			$createdVars{$var} = $input{$var};
		}
	}

	return ($status,%createdVars);
}

sub setRoleProperties {
	my ($varList) = @_;
	$logger->trace("Given ($varList)");

	my ($status,%var) = &getInputs($varList);
	if($status =~ /error/i) {
		return {msg => $status};
	}
	
	if(!defined($var{roleID})) {
		$logger->error("Not given roleID");
		return;
	}
	if(!defined($var{roleName})) {
		$logger->error("Not given roleNam");
		return;
	}
	if(!defined($var{roleDescription})) {
		$logger->error("Not given roleDescription");
		return;
	}

	if(!defined($var{regionID})) {
		$logger->error("Not given regionID");
		return;
	}
	if(!defined($var{metarData})) {
		$logger->error("Not given metarData");
		return;
	}
	if(!defined($var{ltgData})) {
		$logger->error("Not given ltgData");
		return;
	}
	if(!defined($var{graphData})) {
		$logger->error("Not given graphData");
		return;
	}
	if(!defined($var{tickerData})) {
		$logger->error("Not given tickerData");
		return;
	}
	my $dataRef = $db->sqlKey($$sql{setRoleProperties},undef,[$var{regionID},$var{metarData},$var{ltgData},$var{graphData},$var{tickerData},$var{roleDescription},$var{roleID}]);
	my $msg = "Success: Modifying the role with ID '$var{roleID}'";

	my $dbAuth = &dbConnect('authDB');
	my $dbMetar = &dbConnect('metarDB');
	my $dbCloud = &dbConnect;

	my $roleNameDB  = ($dbAuth->sqlKey($$sql{selectRoleNameRef},undef,[$var{roleID}]))[0][0][0];
	my $cloudRoleID = ($dbCloud->sqlKey($$sql{selectvRegionID},undef,[$roleNameDB]))[0][0][0];
	my $metarRoleID = ($dbMetar->sqlKey($$sql{selectvRegionID},undef,[$roleNameDB]))[0][0][0];
	$logger->debug("name: '$roleNameDB'  auth id: $var{roleID}  cloud id:$cloudRoleID  metar id:$metarRoleID");


	# We don't need to change the role name unless the given name is different then the one in the DB
	if($roleNameDB ne $var{roleName}) { 
		$msg = 'warning: Unknow error: Please contact admin with the current time of the error.';
		if(defined($cloudRoleID) && defined($metarRoleID) && defined($roleNameDB)) {
			$msg = "Success: Renamed region with the Auth ID of'$var{roleID}'";

			my $alreadyExistAuth  = ($dbAuth->sqlKey($$sql{authSelectRole},undef,[$var{roleName}]))[0][0][0];
			my $alreadyExistCloud = ($dbCloud->sqlKey($$sql{selectvRegionName},undef,[$var{roleName}]))[0][0][0];
			my $alreadyExistMetar = ($dbMetar->sqlKey($$sql{selectvRegionName},undef,[$var{roleName}]))[0][0][0];
			$logger->debug("Already exist check ($alreadyExistAuth|$alreadyExistCloud|$alreadyExistMetar)");

			if(!defined($alreadyExistAuth) && !defined($alreadyExistCloud) && !defined($alreadyExistMetar)) {
				my $dbAuth   = $dbAuth->sqlKey($$sql{renameRole},undef,[$var{roleName},$var{roleID}]);
				my $dataRef  = $dbCloud->sqlKey($$sql{renameVregion},undef,[$var{roleName},$cloudRoleID]);
				my $dataRef  = $dbMetar->sqlKey($$sql{renameVregion},undef,[$var{roleName},$metarRoleID]);
			} else {
				$msg = "warning: The selected new name already exist!";
			}
		} else {
			$msg = "warning: Problem selecting the needed data to rename the region";
			$logger->warn($msg);
		}
	}

	return {msg => $msg};
}
	
sub userPassword { # Change the user password with teh one that is given
	my ($username,$password) = @_;

	if(!defined($username)) {
		$logger->error("Not given a username");
		return;
	}
	if(!defined($password)) {
		$logger->error("Not given a password");
		return;
	}
	
	my $digest = md5_hex($password); # Super simple hash, should be salted and sha256 or better
	my $dataRef  = $db->sqlKey($$sql{userSetPassword},undef,[$digest,$username]);

	my $msg = "Success: changed user's password";
	return {msg => $msg};
}

sub userDelete {
	my ($userID) = @_;

	if(!defined($userID)) {
		$logger->error("Not given a userID");
		return;
	}

	# FIX: This should be put into a transaction:
	my $dataRef  = $db->sqlKey($$sql{userDeleteRef},undef,[$userID]);
	my $dataRef2  = $db->sqlKey($$sql{userDelete},undef,[$userID]);

	my $msg = "Success: deleted user '$userID'";
	return {msg => $msg};
}

sub userList { # Used for html select drop downs
	my ($username,$needComments) = @_;

	my $dataRef = $db->sqlKey($$sql{userList},'id',["\%$username\%"]);

	my @list;
	foreach my $key (sort {$$dataRef{$a}{username} cmp $$dataRef{$b}{username}} keys %{$dataRef}) { 
		my $comment = $$dataRef{$key}{comments};
		if(!defined($needComments) || !defined($comment)) {
			$list[++$#list] = { name => $$dataRef{$key}{username}, id => $key};
		} else {
			$list[++$#list] = { name => "$$dataRef{$key}{username}  ($comment)", id => $key};
		}
	}

	return \@list;
}

sub authListRoles { # This will take a give user and return a list for jquery: selectList
	my ($userID) = @_;
	
	my @list;
	my $dataRef = $db->sqlKey($$sql{authListRoles},'id');
	
	if(!defined($userID)) {
		$logger->debug("Not given username, creating simple list");
		foreach my $key (sort {$$dataRef{$a}{role} cmp $$dataRef{$b}{role}} keys %{$dataRef}) { 
			$list[++$#list] = { 
				#name => "$$dataRef{$key}{role}  ($$dataRef{$key}{role_description})",
								id => $key,
								role => $$dataRef{$key}{role},
								role_description => $$dataRef{$key}{role_description},
								country_code => $$dataRef{$key}{country_code},
								metar => $$dataRef{$key}{metar_data},
								ltg => $$dataRef{$key}{ltg_data},
								graph => $$dataRef{$key}{graph_data},
								ticker => $$dataRef{$key}{ticker}
							};
		}
	} else {
		my $userRef = $db->sqlKey($$sql{userGivenRoles},'id',[$userID]);
		foreach my $key (sort {$$dataRef{$a}{role} cmp $$dataRef{$b}{role}} keys %{$dataRef}) { 
			my $used = 0;
			# $logger->info("#$$dataRef{$key}{id}#");
			if(defined($$userRef{$$dataRef{$key}{id}})) { # if the given user has the given role lets set a flag
				$used = 1;
			}	
			$list[++$#list] = { role => "$$dataRef{$key}{role}  ($$dataRef{$key}{role_description})", id => $key, used => $used};
		}
	}

	return \@list;
}

sub authListRoles2 { # This will take a give user and return a list for jquery: selectList

	my @list;
	my $dataRef = $db->sqlKey($$sql{authListRoles},'id');

	foreach my $key (sort {$$dataRef{$a}{role} cmp $$dataRef{$b}{role}} keys %{$dataRef}) { 
		$list[++$#list] = { id => $key, 
							name => $$dataRef{$key}{role},
							description => $$dataRef{$key}{role_description},
						};
	}

	return \@list;
}
###############################################################################################
sub createTableDataShort {
	my ($varList) = @_;
	$logger->trace("Given ($varList)");

	my ($status,%var) = &getInputs($varList);
	if($status =~ /error/i) {
		return {msg => $status};
	}

	# use Data::Dumper;
	# my $test = Dumper(\%var);
	# $logger->inf("#$test#");
	# exit;

	# stationIdentitySearch=	SELECT 
	# 	si.stn_id,
	# 	si.xml_target_name,
	# 	si.station_name,
	# 	EXTRACT(EPOCH FROM si.last_updated) AS last_updated,
	# 	si.lat,
	# 	si.lon,
	# 	si.alt,
	# 	si.region_id,
	# 	si.image1_url,
	# 	si.forecast_url

	my $sql = $$sql{stationIdentitySearch};

	$sql .= ' LIMIT 10 OFFSET 10';

	my $data = $db->sqlKey($sql,'xml_target_name',[]);
	my @header  = ('Station Name','XML Name','Last Updated','Latitude','Longitude','Altitude','Region ID','Image1 URL','Forecast URL');
	my @dataSet = qw(station_name xml_target_name last_updated lat lon alt region_id image1_url forecast_url);

	my @rows;
	foreach my $key (sort keys(%{$data})) {
		my %columnData;
		foreach my $line (@dataSet) {
			my $value = $$data{$key}{$line};
			if($value eq 'null') {	
				$value = '';
			}
			$columnData{$line} = $value;
		}
		$rows[++$#rows] = \%columnData;
	}

	# use Data::Dumper;
	# my $test = Dumper(\@rows);
	# $logger->info("------------------> #$test#");

	my %tablesorterData = ( # This is the format that is needed for tablesorter
		total_rows => $#rows+1,
		headers => \@header,
		rows   => \@rows
	);
							
	return \%tablesorterData;
};

sub createTableDataPager {
	my ($tableMap,$varList) = @_;
	$logger->trace("Given ($tableMap,$varList)");
	my ($status,%var) = &getInputs($varList);
	if($status =~ /error/i) {
		return {msg => $status};
	}
	
	my $tableSQL = $$tableMap{sqlCall};
	my $groupBy = $$sql{$$tableMap{sqlCallGroupBy}};
	my $sortKey = $$tableMap{sortKey};
	my $useDB = $$tableMap{useDB};
	# Make sure we have good user input:
	if(!defined($tableMap)) {
		$logger->error("Not given tableMap");
		return;
	}
	if(!defined($tableSQL)) {
		$logger->error("Not given tableSQL");
		return;
	}
	if(!defined($useDB)) {
		$logger->error("Not given useDB");
		return;
	}
	if(!defined($sortKey)) {
		$logger->error("Not given sortKey");
		return;
	}
	if(!defined($$sql{$tableSQL})) {
		$logger->error("tableSQL: $tableSQL doesn't exist in SQL file.");
		return;
	}

	my $currentDB;
	if($useDB eq 'metar') {
		$currentDB = &dbConnect('metarDB');
	} elsif($useDB eq 'auth') {
		$currentDB = &dbConnect('authDB');
	} else {
		$currentDB = &dbConnect;
	}

	my ($dynamicSQL,@dynamicInputs,$data);

	# use Data::Dumper;
	# my $test = Dumper(\$tableMap);
	# $logger->trace($test);

	my $filterSQL = 'WHERE';
	my $switch = 0;
	for(my $i=0; $i <= $#{$var{filter}}; $i++) {
		if(defined(${$var{filter}}[$i])) {
			# There might be a small bug here, it might be presumptuous to have "-"
			if(${$var{filter}}[$i] =~ /^[\-\d\.]+$/) { # What if we get a number, the like doesn't work all that great
				$filterSQL .= " CAST($$tableMap{order}[$i] AS TEXT) LIKE ? AND"
			} else {
				## ilike is similar to like but case insensitive
				$filterSQL .= " $$tableMap{order}[$i] ILIKE ? AND";
			}

			my $var = ${$var{filter}}[$i];
			$var =~ s/([\%_])/\\$1/g; # So we don't want invoke postgres pattern matching, arg
			$dynamicInputs[++$#dynamicInputs] = "\%$var\%";
			$switch = 1;
		}
	};
	substr($filterSQL, -4) = ''; # remove the last AND
	if($switch == 0) {
		$filterSQL = '';
	}
	# $logger->trace("---------------> filterSQL #$filterSQL#@dynamicInputs#");

	my $sortSQL = 'ORDER BY';
	$switch = 0;
	for(my $i=0; $i <= $#{$var{column}}; $i++) {
		# You can not use table or column names with place holders
		if(defined(${$var{column}}[$i])) {
			my $name = $currentDB->quote_identifier($$tableMap{order}[$i]);
			if(${$var{column}}[$i] == 1) {
				$sortSQL .= " $name ASC,";
			} else {
				$sortSQL .= " $name DESC,";
			}
			$switch = 1;
		}
	};
	chop($sortSQL);
	if($switch == 0) {
		$sortSQL = '';
	}
	# $logger->trace("---------------> sortSQL #$sortSQL#");

	my $countSQL = "select count(*) from ($$sql{$tableSQL} $groupBy) AS b $filterSQL";
	my $rowCount = ($currentDB->sqlKey($countSQL,undef,[@dynamicInputs]))[0][0][0];
	$logger->debug("row count: '$rowCount'");

	# Add limits
	$dynamicInputs[++$#dynamicInputs] = $var{size};
	$dynamicInputs[++$#dynamicInputs] = $var{page}*$var{size};
	$dynamicSQL = "select * from ($$sql{$tableSQL} $groupBy $sortSQL) as b $filterSQL LIMIT ? OFFSET ?";
	$logger->debug("SQL: '$dynamicSQL'");


	$data = $currentDB->sqlArrayHash($dynamicSQL,[@dynamicInputs]);
	# use Data::Dumper;
	# my $test = Dumper(\$data);
	# $logger->trace($test);
 
	my @header;
	foreach my $key (@{$$tableMap{order}}) {
		$header[++$#header] = $$tableMap{map}{$key};
	}

	my %webData;
	$webData{headers} = \@header;
	foreach my $row (@{$data}) {
		my @array;
		# foreach my $var (@{$metaData{stationAssociation}{dataSet}}) {
		foreach my $var (@{$$tableMap{order}}) { # If the full path is one we are using return just the short name
			my $neededData;
			if($var eq 'image1_url' || $var eq 'forecast_url' ) { # Will not need this in the future
				my $file = ($$row{$var} =~ /([^\/]*$)/)[0];
				$neededData = $file;
			} else {
				$neededData = $$row{$var};
			}
			if(!defined($neededData)) {
				$neededData = '';
			}
			$array[++$#array] = $neededData;
		}
		$webData{ids}[++$#{$webData{ids}}] = $$row{$sortKey};
		$webData{rows}[++$#{$webData{rows}}] = \@array;
	}
	#$logger->debug("Database returned row count: '$count'");

	$webData{names} = $$tableMap{order};
	$webData{total_rows} = $rowCount;
	return \%webData;
}

sub getStationList {
	my ($stationID,$xmlName,$regionID,$vRegion) = @_;
	$logger->info("given #$stationID#$xmlName#$regionID#$vRegion#");
	
	if(!defined($stationID) && !defined($xmlName) && !defined($regionID) && !defined($vRegion)) {
		$logger->warn("No data given, so just returning");
		return;
	}
	
	my $dynamicSQL  = $$sql{stationList} ." WHERE "; # we are going to use a normal sql query and add a filter
	
	my @varList;
	if(defined($stationID)) {
		foreach my $var (split(/\,/,$stationID)) {
			$dynamicSQL .= "s.stn_id=? OR ";
			$varList[++$#varList] = $var;
		}
	}
	if(defined($xmlName)) {
		foreach my $var (split(/\,/,$xmlName)) {
			$dynamicSQL .= "s.xml_target_name=? OR ";
			$varList[++$#varList] = $var;
		}
	}
	if(defined($regionID)) {
		foreach my $var (split(/\,/,$regionID)) {
			$dynamicSQL .= "s.region_id=? OR ";
			$varList[++$#varList] = $var;
		}
	}
	if(defined($vRegion)) {
		foreach my $var (split(/\,/,$vRegion)) {
			$dynamicSQL .= "v.v_region_id=? OR ";
			$varList[++$#varList] = $var;
		}
	}
	$dynamicSQL =~ s/ OR $//;
	
	# $logger->info("sql #$sql#");
	# $logger->info("vars #@varList#");
	my $data = $db->sqlKey($dynamicSQL,'stn_id',[@varList]);

	# use Data::Dumper;
	# my $test = Dumper(\$db);
	# $logger->info("#$test#");
	
	return $data;
}

sub getStationName {
	my ($searchVar) = @_;
	# $logger->trace("#$searchVar#");
	
	my $data = $db->sqlKey($$sql{stationName},'stn_id',["\%$searchVar\%"]);

	my $jsonData;
	foreach my $id (keys %{$data}) {
		$$jsonData[++$#$jsonData] = { name => $$data{$id}{'station_name'}, id => $id};
	}

	return $jsonData;
}

sub getXMLname {
	my ($searchVar) = @_;
	# $logger->trace("#$searchVar#");
	
	my $data = $db->sqlKey($$sql{xmlName},'stn_id',["\%$searchVar\%"]);

	my $jsonData;
	foreach my $id (keys %{$data}) {
		# $$jsonData[++$#$jsonData] = { name => $$data{$id}{'xml_target_name'}, id => $id};
		$$jsonData[++$#$jsonData] = { name => $$data{$id}{'xml_target_name'}, id => $$data{$id}{'xml_target_name'} };
	}

	return $jsonData;
}

sub getRegion {
	my ($searchVar) = @_;
	my $data = $db->sqlKey($$sql{region},undef,["\%$searchVar\%"]);

	my $jsonData;
	foreach my $name (@{$data}) {
		$$jsonData[++$#$jsonData] = { name => $$name[0], id => $$name[0]};
	}

	return $jsonData;
}
sub getVregion {
	my ($searchVar) = @_;
	my $data = $db->sqlKey($$sql{vRegion},undef,["\%$searchVar\%"]);

	my $jsonData;
	foreach my $name (@{$data}) {
		$$jsonData[++$#$jsonData] = { name => $$name[1], id => $$name[0]};
	}

	return $jsonData;
}
sub getOrgRegion {
	my ($searchVar) = @_;
	my $data = $db->sqlKey($$sql{orgRegion},undef,["\%$searchVar\%","\%$searchVar\%"]);
	
	my $jsonData;
	foreach my $name (@{$data}) {
		$logger->trace("#@{$name}#");
		$$jsonData[++$#$jsonData] = { name => "$$name[1] ($$name[0])", id => $$name[1]};
	}

	return $jsonData;
}
sub getOrganization {
	my ($searchVar) = @_;
	my $data = $db->sqlKey($$sql{organization},undef,["\%$searchVar\%"]);

	my $jsonData;
	foreach my $name (@{$data}) {
		$$jsonData[++$#$jsonData] = { name => $$name[0], id => $$name[0]};
	}

	return $jsonData;
}

sub deleteVirtualRegionMap {
	my ($stationList,$vRegion,$addedBy,$description) = @_;
	$logger->info("given #$stationList#$vRegion#$addedBy#$description#");
	
	# We don't need $addedBy or $description but this will create logs with some info problems that might be found later
	# Maybe in future versions this will be removed

	if(!defined($stationList) || !defined($vRegion) || !defined($addedBy) || !defined($description)) {
		my $msg = "Needed data not given, so just returning";
		$logger->warn($msg);
		return {msg => $msg};
	}

	if(!defined($$sql{selectRoleNameRef})) {
		$logger->logcroak("searchSQL 'selectRoleNameRef' doesn't exist in sql file.");
	}
	if(!defined($$sql{selectvRegionID})) {
		$logger->logcroak("searchSQL 'selectvRegionID' doesn't exist in sql file.");
	}
	if(!defined($$sql{deleteVregionMap})) {
		$logger->logcroak("searchSQL 'deleteVregionMap' doesn't exist in sql file.");
	}
	if(!defined($$sql{selectVregionMap})) {
		$logger->logcroak("searchSQL 'selectVregionMap' doesn't exist in sql file.");
	}

	my $dbAuth = &dbConnect('authDB');
	my $roleName = ($dbAuth->sqlKey($$sql{selectRoleNameRef},undef,[$vRegion]))[0][0][0];
	my $roleID = ($db->sqlKey($$sql{selectvRegionID},undef,[$roleName]))[0][0][0];
	
	if(!defined($roleName) || !defined($roleID)) {
		my $msg = "warning: Needed data not found in database. Please contact admin with the time of the error";
		$logger->warn($msg);
		return {msg => $msg};
	}

	my $counterDelete = 0;
	foreach my $stationID (split(/\,/,$stationList)) {
		$logger->trace("stationID: $stationID");
		my $inserted = (keys(%{$db->sqlKey($$sql{selectVregionMap},'id',[$stationID,$roleID])}))[0];

		if(defined($inserted)) {
			$logger->trace("Going to delete station '$stationID' from mapping");
			my $data = $db->sqlKey($$sql{deleteVregionMap},undef,[$stationID,$roleID]);
			$counterDelete++;
		} else {
			my $msg = "warning: Station was not set in mapping: stationID:$stationID regionID:$roleID";
			$logger->warn($msg);
			# return {msg => $msg};
		}
		
	}

	my $msg = "Deleted:$counterDelete";
	return {msg => $msg};
}
	
sub setVirtualRegionMap { # This will add or update the REF table with meta data 
	my ($stationList,$vRegion,$addedBy,$description) = @_;
	$logger->info("given #$stationList#$vRegion#$addedBy#$description#");
	
	if(!defined($stationList) || !defined($vRegion) || !defined($addedBy) || !defined($description)) {
		my $msg = "Needed data not given, so just returning";
		$logger->warn($msg);
		return {msg => $msg};
	}

	if(!defined($$sql{selectRoleNameRef})) {
		$logger->logcroak("searchSQL 'selectRoleNameRef' doesn't exist in sql file.");
	}
	if(!defined($$sql{selectvRegionID})) {
		$logger->logcroak("searchSQL 'selectvRegionID' doesn't exist in sql file.");
	}
	if(!defined($$sql{deleteVregionMap})) {
		$logger->logcroak("searchSQL 'deleteVregionMap' doesn't exist in sql file.");
	}
	if(!defined($$sql{selectVregionMap})) {
		$logger->logcroak("searchSQL 'selectVregionMap' doesn't exist in sql file.");
	}

	my $dbAuth = &dbConnect('authDB');
	my $roleName = ($dbAuth->sqlKey($$sql{selectRoleNameRef},undef,[$vRegion]))[0][0][0];
	my $roleID = ($db->sqlKey($$sql{selectvRegionID},undef,[$roleName]))[0][0][0];
	
	if(!defined($roleName) || !defined($roleID)) {
		my $msg = "warning: Needed data not found in database. Please contact admin with the time of the error";
		$logger->warn($msg);
		return {msg => $msg};
	}

	my $counterInsert = 0;
	my $counterUpdate = 0;
	foreach my $stationID (split(/\,/,$stationList)) {
		my $inserted = (keys(%{$db->sqlKey($$sql{selectVregionMap},'id',[$stationID,$roleID])}))[0];
		$logger->trace("inserted: #$inserted#");

		if(defined($inserted)) { # If we already have the needed data in the reference table lets just update the meta data
			$logger->trace('Already inserted, just updating');
			my $data = $db->sqlKey($$sql{updateVregionMap},undef,[$addedBy,$description,$stationID,$roleID]); # Need: (stn_id,v_region_id,added_by,comments)
			$counterUpdate++;
		} else {
			$logger->trace('Inserting new row');
			$logger->trace("sql [$stationID,$roleID,$addedBy,$description]");
			my $data = $db->sqlKey($$sql{insertVregionMap},undef,[$stationID,$roleID,$addedBy,$description],undef,undef,'noReturn'); # Need: (stn_id,v_region_id,added_by,comments)
			$counterInsert++;
		}
	}

	my $msg = "Inserted:$counterInsert  Updated:$counterUpdate";
	return {msg => $msg};
}

###############################################################################################
###############################################################################################
# General func that work with more then one type of data


sub simpleTable { # General func to return a hash with needed info to create a jquery/json table
	my ($tableSQL,$tableMap) = @_;
	$logger->trace("Given ($tableSQL,$tableMap)");

	#Example maptable hash:
	# my %tableMap = (
	# 	order => [qw(role role_description )],
	# 	map => {
	# 		role => 'Role',
	# 		role_description => 'Description',
	# 	}
	# );


	# Make sure we have good user input:
	if(!defined($tableSQL)) {
		$logger->error("Not given tableSQL");
		return;
	}
	if(!defined($tableMap)) {
		$logger->error("Not given tableMap");
		return;
	}
	if(!defined($$sql{$tableSQL})) {
		$logger->error("tableSQL: $tableSQL doesn't exist in SQL file.");
		return;
	}

	my $data = $db->sqlKey($$sql{$tableSQL},'id');

	my @header;
	foreach my $key (@{$$tableMap{order}}) {
		# $logger->trace("KEY: #$key#");
		$header[++$#header] = $$tableMap{map}{$key};
	}

	my %webData;
	$webData{header} = \@header;

	foreach my $id (keys %{$data}) {
		my @group;
		foreach my $var (@{$$tableMap{order}}) { # If the full path is one we are using return just the short name
			if(    ($var eq 'image1_url'   && $$data{$id}{$var} =~ /^$$env{imageURL}/)
				|| ($var eq 'forecast_url' && $$data{$id}{$var} =~ /^$$env{jsonURL}/)
			) {
				my $file = ($$data{$id}{$var} =~ /([^\/]*$)/)[0];
				$group[++$#group] = $file;
			} else {
				$group[++$#group] = $$data{$id}{$var};
			}
		}
		#my $test = join("|", @group);
		#$logger->trace("HERE: $test");
		$webData{data}[++$#{$webData{data}}] = \@group;
	}

	return \%webData;
}

sub simpleList {
	my ($searchSQL) = @_;
	$logger->trace("Given ($searchSQL) converts to ($$sql{$searchSQL})");
	
	if(!defined($$sql{$searchSQL})) {
		$logger->logcroak("searchSQL '$searchSQL' doesn't exist in sql file.");
	}

	my $data = $db->sqlKey($$sql{$searchSQL},'id');

	my $jsonData;
	foreach my $id (sort {$$data{$a}{'var'} cmp $$data{$b}{'var'}} keys %{$data}) {
		$$jsonData[++$#$jsonData] = { name => $$data{$id}{'var'}, id => $id};
	}

	return $jsonData;
}

###############################################################################################

sub dbConnect {
	my ($databaseSet) = @_;

	# if($self->{dbConnected}) { # we don't need to connect to the db if we have already
		# return;
	# }
	
	my $dbh = DBpg->new;
	if($databaseSet eq 'metarDB') {
		$logger->info("Using: metarDB");
		$dbh->connect($$env{metardbServer},$$env{metardbName},$$env{metardbUser},$$env{metardbPass},$$env{metardbPort});
	} elsif($databaseSet eq 'authDB') {
		$logger->info("Using: authDB");
		$dbh->connect($$env{authdbServer},$$env{authdbName},$$env{authdbUser},$$env{authdbPass},$$env{authdbPort});
	} else {
		$dbh->connect($$env{dbServer},$$env{dbName},$$env{dbUser},$$env{dbPass},$$env{dbPort});
	}
	
	# $db->sql("SET search_path TO oe");
	
	return $dbh;
}

sub help {
	my $tt = Template->new({ # Create template object
		INCLUDE_PATH => "$basePath${slash}$$env{templateDir}",
		INTERPOLATE  => 0,
	}) || $logger->logcroak($Template::ERROR);

	my $vars = {
		debug => 0,
	};

	print "Content-Type: text/html; charset=utf-8\n\n";
	$tt->process('rest.help.html', $vars) || $logger->logcroak($tt->error());
	
	exit;
}

###############################################################################################

