package DBpg;
# Author:  Ryan Wilcox
# Description: This module is to interface with a postgresql DB
my $version = '0.8a';

our ($os,$mwd,$mName,$basePath,$slash);
BEGIN {
	($mwd,$mName) = (__FILE__ =~ /(.*)[\\|\/]([^\\|\/]*$)/); # module working directory
	$os = $^O;
	$slash = '/';
	$basePath = "$mwd${slash}..";
	# Add these paths to the end of the search array. NOTE: use lib adds the beginning.
	$INC[++$#INC] = "$basePath${slash}lib"; # perl libs/mods
}

use strict;
use Carp; # issue warnings from calling code.
use DBI; # apt-get install libdbi-perl libdbd-pg-perl
use Util; # Basic Utils

our $logger; # Logger handler
# our ($retryOnerror,$retryOnerrorCount,$gdbServer,$gdbName,$gdbUser,$gdbPass);
###############################################################################################
sub new {
	my $proto = shift;
	my $class = ref($proto) || $proto;
	my $self  = {};

	$logger->trace("Creating new object $mName");
	# $self->{retryOnerror} = 0;
	# $self->{retryOnerrorCount} = 0;

	bless($self);           # but see below
	$self->{ParentPID} = $$; # Need to make this code fork safe
	
	return $self;
 }

sub DESTROY {
	my $self = shift;

	if($self->{ParentPID} == $$) {
		$self->disconnect;
	} else { # DBI and forking is a problem: http://www.perlmonks.org/?node_id=594175
		$self->{dbh}->{InactiveDestroy} = 1;
		$self->{dbh} = undef;
	}
	
	return;
}
###############################################################################################
sub connect {
	my ($self,$dbServer,$dbName,$dbUser,$dbPass,$dbPort,$noAutoCommit) = @_;
	# $logger->trace("Given ($dbServer,$dbName,$dbUser,$dbPass,$dbPort,$noAutoCommit)");

	if(!defined($self->{dbUser})) { # We would get here if this was the first time 'connect' was called
		$self->{dbUser}	= $dbUser;
		$self->{dbPass}	= $dbPass;
		$self->{dbName}	= $dbName;
		$self->{dbServer} = $dbServer;
		$self->{dbPort} = $dbPort;
		if(!defined($noAutoCommit)) {
			$self->{autoCommit} = 0;
		} else {
			$self->{autoCommit} = 1;
		}
	} else {
		undef $self->{dbh};
	}

	if(!defined($self->{dbPort})) {
		$self->{dbPort} = 5432;
	}

	$logger->trace("Creating connection: ($self->{dbName},$self->{dbServer},$self->{dbPort},$self->{dbUser},$self->{dbPass})");
	$self->{dbh} = DBI->connect("dbi:Pg:dbname=".$self->{dbName}.";host=".$self->{dbServer}.";port=".$self->{dbPort}, $self->{dbUser}, $self->{dbPass},
	{
		ShowErrorStatement => 1,
		RaiseError => 1,
		PrintError => 0,
		AutoCommit => $self->{autoCommit},
		HandleError=> \&dbiErrorHandler,
	}) || $logger->logcroak("Could not connect to database: $DBI::errstr");

	return;
}

sub setSql {
	my ($self,$sqlHashRef) = @_;

	if(!defined($sqlHashRef)) {
		$logger->logcroak("Not given needed input 'sqlHashRef'");
	}
	
	$self->{sql} = $sqlHashRef;
	
	return;
}

sub retryOnerror { # Let the user set the option to try and reconnect to the DB if there is a problem
	my $self = shift;
	
	$self->{retryOnerror} = 1;

	return;
}

sub disconnect {
	my $self = shift;
	$logger->trace("disconnecting from DB");
	
	$$self{sth}->finish() if ($$self{sth});
	$$self{dbh}->disconnect if ($$self{dbh}); # Disconnect the database from the database handle.
	
	return;
}

sub sql {
	my $self = shift;
	my ($sqlcmd,$noCommit) = @_;
	$logger->trace("SQL: $sqlcmd");
	
	my $sth = $$self{dbh}->prepare($sqlcmd) || $logger->logcroak("Can't prepare statement: $DBI::errstr");
	$sth->execute || $logger->logcroak("Can't execute sql: $sqlcmd");
	if(!defined($noCommit) && $self->{autoCommit} == 0){
		$logger->trace("Commited");
		$$self{dbh}->commit();
	}

	my @data;
	if($sth->{NUM_OF_FIELDS}) { # was it a SELECT statement?
		while(my $hashref = $sth->fetchrow_hashref()) {
			$data[++$#data] = $hashref;
		}
	}

	return \@data;
}

sub sqlKey2 { # IF the user just wants to pass the key to the sql hash
	my $self = shift;
	my ($sqlKey,$key,$paramsRef,$noCommit,$singleVar) = @_;
	$logger->trace("Given ($sqlKey,$key,$paramsRef,$noCommit,$singleVar)");

	return $self->sqlKey($$self->{sql}{$sqlKey},$key,$paramsRef,$noCommit,$singleVar);
}

sub sqlKey {
	my $self = shift;
	my ($sqlcmd,$key,$paramsRef,$noCommit,$singleVar,$noReturn) = @_;
	#$logger->trace("Given ($sqlcmd,$key,$paramsRef,$noCommit,$singleVar,$noReturn)");
	# key			= The column to sort by
	# paramsRef		= IF Anonymous array: [$var1,$var2,$var3]
	#				  IF singleVar:       $var	  If you want to pass only one variable and have it used for all ? in the sql statement
	
	my $cntCmd   = @{[$sqlcmd =~ /(\?)/g]}; # count the number of time "?" is in the string command
	my @params;
	
	if(defined($paramsRef)) {
		if(ref($paramsRef) eq 'ARRAY') { # if the user gave us an array, lets map that
			@params = @$paramsRef;
		} else { # if the user only gave us one variable, then lets map that one to all sql question marks
			$logger->trace("User gave only one variable. Mapping given variable to all question marks.");
			for(my $i=0; $i < $cntCmd; $i++) {
				$params[++$#params] = $paramsRef;
			}
		}
	}

	$logger->debug("DB:$self->{dbName}  SQL: $sqlcmd");
	if($logger->is_debug) {
		my $paramCount = $#params+1;
		my $paramList = join('|',@params);
		$logger->debug("sqlKey params($paramCount) [$paramList]");
	}
	if(!defined($sqlcmd)) { $logger->logcroak("SQL command not given"); }

	
	my $cntParam = @params;
	if($cntCmd != $cntParam) {
		$logger->logcroak("Number of params given and needed did not match. Need ($cntCmd), got ($cntParam)");
	}
	
	my $sth = $$self{dbh}->prepare($sqlcmd) || $logger->logcroak("Can't prepare statement: $DBI::errstr");
	my $i = 1;
	foreach my $var (@params) {
		#$logger->trace("bind_param ($i,$var)");
		$sth->bind_param($i,$var);
		$i++;
	}

	# my $generatedSQL = $sth->{Statement};
	# $logger->debug("DB:$self->{dbName}  SQL: $generatedSQL");

	my $rv = $sth->execute || $logger->logcroak("Can't execute sql: $sqlcmd");
	if(!defined($noCommit) && $self->{autoCommit} == 0){
		$logger->trace("Commited");
		$$self{dbh}->commit();
	}

	my $returnData;
	if($sth->{NUM_OF_FIELDS}) { # was it a SELECT statement?
		if(!defined($key)) {
			$logger->trace("No key given, using fetchall_arrayref");
			$returnData = $sth->fetchall_arrayref(); # This is a array Ref
		} else {
			$returnData = $sth->fetchall_hashref($key); # This is a Hash Ref
		}
	} elsif($sqlcmd =~ /insert into (\w+\.)?(\w+) \(([\w]+)/i) { # Return the ID for an insert
		my ($schema,$table,$colm) = ($1,$2,$3); # we don't want the table name with the schema oe.test_table
		$schema =~ s/\.$//; # remove the . in the schema name
		
		if(!defined($schema)) {
			$schema = 'public';
		}

		$logger->trace("Getting last_insert_id with this info ($schema,$table,$colm)");
		if(!defined($noReturn)) {
			$returnData = $$self{dbh}->last_insert_id(undef, $schema, $table, $colm);
		}
		
		
	}

	return $returnData;
}

sub sqlArrayHash {
	my $self = shift;
	my ($sqlcmd,$paramsRef,$noCommit,$singleVar,$noReturn) = @_;
	#$logger->trace("Given ($sqlcmd,$paramsRef,$noCommit,$singleVar,$noReturn)");
	# paramsRef		= IF Anonymous array: [$var1,$var2,$var3]
	#				  IF singleVar:       $var	  If you want to pass only one variable and have it used for all ? in the sql statement
	
	my $cntCmd   = @{[$sqlcmd =~ /(\?)/g]}; # count the number of time "?" is in the string command
	my @params;
	
	if(defined($paramsRef)) {
		if(ref($paramsRef) eq 'ARRAY') { # if the user gave us an array, lets map that
			@params = @$paramsRef;
		} else { # if the user only gave us one variable, then lets map that one to all sql question marks
			$logger->trace("User gave only one variable. Mapping given variable to all question marks.");
			for(my $i=0; $i < $cntCmd; $i++) {
				$params[++$#params] = $paramsRef;
			}
		}
	}

	$logger->debug("DB:$self->{dbName}  SQL: $sqlcmd");
	if($logger->is_debug) {
		my $paramCount = $#params+1;
		my $paramList = join('|',@params);
		$logger->debug("sqlKey params($paramCount) [$paramList]");
	}
	if(!defined($sqlcmd)) { $logger->logcroak("SQL command not given"); }

	
	my $cntParam = @params;
	if($cntCmd != $cntParam) {
		$logger->logcroak("Number of params given and needed did not match. Need ($cntCmd), got ($cntParam)");
	}
	
	my $sth = $$self{dbh}->prepare($sqlcmd) || $logger->logcroak("Can't prepare statement: $DBI::errstr");
	my $i = 1;
	foreach my $var (@params) {
		#$logger->trace("bind_param ($i,$var)");
		$sth->bind_param($i,$var);
		$i++;
	}

	# my $generatedSQL = $sth->{Statement};
	# $logger->debug("DB:$self->{dbName}  SQL: $generatedSQL");

	my $rv = $sth->execute || $logger->logcroak("Can't execute sql: $sqlcmd");
	if(!defined($noCommit) && $self->{autoCommit} == 0){
		$logger->trace("Commited");
		$$self{dbh}->commit();
	}

	my $returnData;
	if($sth->{NUM_OF_FIELDS}) { # was it a SELECT statement?
		$logger->trace("No key given, using fetchall_arrayref");
		$returnData = $sth->fetchall_arrayref({}); # This will return an array of hashes
	} elsif($sqlcmd =~ /insert into (\w+\.)?(\w+) \(([\w]+)/i) { # Return the ID for an insert
		my ($schema,$table,$colm) = ($1,$2,$3); # we don't want the table name with the schema oe.test_table
		$schema =~ s/\.$//; # remove the . in the schema name
		
		if(!defined($schema)) {
			$schema = 'public';
		}

		$logger->trace("Getting last_insert_id with this info ($schema,$table,$colm)");
		if(!defined($noReturn)) {
			$returnData = $$self{dbh}->last_insert_id(undef, $schema, $table, $colm);
		}
		
		
	}

	return $returnData;
}

sub quote_identifier {
	my $self = shift;
	my ($key) = @_;

	# You can not use table or column names with place holders
	# http://stackoverflow.com/questions/1862501/perl-using-dbi-placeholders-for-order-by-clause

	return $$self{dbh}->quote_identifier($key);
}

sub dbiErrorHandler { # Handle the mysql error ourselfs
	my ($message,$handle,$first_value) = @_;
	# my ($self) = @_;

	# if($self->{retryOnerror} == 1 && $self->{retryOnerrorCount} < 5) { # if the user wants to retry the DB connect on errors
		# $logger->warn($DBI::errstr);
		# $self->disconnect;
		# sleep 2;
		# $self->{retryOnerrorCount}++;
		# $self->connect;
	# } else {	
		$logger->logcroak("DBI Error: ".$DBI::errstr);
	# }
	
	croak("DBI Error: ".$DBI::errstr);
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

# http://www.tutorialspoint.com/perl/perl_database.htm
  # $dsn    Database source name
  # $dbh    Database handle object
  # $sth    Statement handle object
  # $h      Any of the handle types above ($dbh, $sth, or $drh)
  # $rc     General Return Code  (boolean: true=ok, false=error)
  # $rv     General Return Value (typically an integer)
  # @ary    List of values returned from the database.
  # $rows   Number of rows processed (if available, else -1)
  # $fh     A filehandle
  # undef   NULL values are represented by undefined values in Perl
  # \%attr  Reference to a hash of attribute values passed to methods