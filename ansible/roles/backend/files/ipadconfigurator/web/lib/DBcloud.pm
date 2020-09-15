package DBnms;
# Author:  Ryan Wilcox
# Description: This module is to interface with the NMS DB

our ($os,$mwd,$mName,$basePath,$slash);
BEGIN {
	($mwd,$mName) = (__FILE__ =~ /(.*)[\\|\/]([a-zA-Z0-9]+).pm/); # module work directory
	$os = $^O;
	$slash = '/';
	$basePath = "$mwd${slash}..";
	# Add these paths to the end of the search array. NOTE: use lib adds the beginning.
	$INC[++$#INC] = "$basePath${slash}lib"; # perl libs/mods
	
	@ISA = ("DBpg"); # extend the current name space to also search in DBmysql
}

use strict;
use Carp; # issue warnings from calling code.
use DBpg; # PostgreSQL DB module
use Util; # Basic Utils

our $logger; # Logger handler
our $configFolder = "$basePath${slash}config${slash}"; # the location of the configs
our ($env,$sql);
###############################################################################################
sub new {
	my $proto = shift;
	my $class = ref($proto) || $proto;
	my $self  = {};
	bless($self);           # but see below
	$logger->debug("Creating new object $mName");

	$env = &Util::readDynamicConfigPre("${configFolder}environment.cfg"); # Environmental paths
	$sql = &Util::readDynamicConfigPre("${configFolder}sqlCalls.NMS.cfg"); # File that  holds SQL code

	if(!defined($$env{dbServer})) {
		$logger->logcroak("Missing dbServer from config");
	}
	if(!defined($$env{dbName})) {
		$logger->logcroak("Missing dbName from config");
	}
	if(!defined($$env{dbUser})) {
		$logger->logcroak("Missing dbUser from config");
	}
	if(!defined($$env{dbPass})) {
		$logger->logcroak("Missing dbPass from config");
	}

	$self->{dbServer} = $$env{dbServer};
	$self->{dbName}	= $$env{dbName};
	$self->{dbUser} = $$env{dbUser};
	$self->{dbPass} = $$env{dbPass};
	$self->connect($self->{dbServer},$self->{dbName},$self->{dbUser},$self->{dbPass}); # DBpg object, connect to the NMS postgres DB

	return $self;
}

sub DESTROY {
	my $self = shift;

	$self->disconnect; # DBpg object
}
###############################################################################################
sub startRun{
	my ($self,$domainName,$startDate,$duration) = @_;
	$logger->trace("Given ($domainName,$startDate,$duration)");
	
	# my ($package,$filename,$line) = caller;
	# print "($package,$filename,$line)\n";
	# exit;
	
	if(!defined($domainName)) {
		$logger->logcroak("Missing domainName from config");
	}
	if(!defined($startDate)) {
		$logger->logcroak("Missing startDate from config");
	}
	if(!defined($duration)) {
		$logger->logcroak("Missing duration from config");
	}


	my $dataRef = $self->sqlKey($$sql{checkProgressGroup},undef,[$domainName,$startDate,$duration]);

	my $runID = $$dataRef[0][0];
	if(!defined($runID)) {
		$logger->debug("No runID found, going to insert a new run");
		$runID = $self->sqlKey($$sql{addProgressGroup},undef,[$domainName,$startDate,$duration],'returnArray');
		$dataRef = $self->sqlKey($$sql{addProgressStep},undef,[$runID,'Start']);
	}

	$self->{runID} = $runID;
	return;
}

sub updateStepDuration {
	my ($self,$step,$duration) = @_;

	if(!defined($self->{runID})) {
		$logger->logcroak('Error: missing needed variable runID. Did you forget to run startRun?');
	}

	$self->sqlKey($$sql{updateStepDuration},undef,[$duration,$step,$self->{runID}]);

	return;
}

sub startStep {
	my ($self,$step,$duration) = @_;

	if(!defined($self->{runID})) {
		$logger->logcroak('Error: missing needed variable runID. Did you forget to run startRun?');
	}

	$self->sqlKey($$sql{addProgressStep},undef,[$self->{runID},$step]);

	return;
}

sub logger {
	my $self = shift;
	my ($givenLogger) = @_;
	if(!defined($givenLogger)) {
		$logger->logcroak("Error: This module needs to be given a logging interface");
	}
	
	# set the local logger to the one given
	$logger = $givenLogger;
	
	return;
}
###############################################################################################
1; # must return somthing!