package Util;
# Author:  Ryan Wilcox
# Description: This lib is for generic functions
my $version = '0.1';

use strict;
#use warnings; # warnings can help catch logic errors, and typos
use Carp; # issue warnings from calling code.
use IO::File; # Use file handles with scope
use IO::Dir; # Use dir handles with scope
use File::Path qw(mkpath rmtree); # used to recursively create/delete a directory structure;
use File::stat; # OO way for stat() functions

# warn File::Path->VERSION;
# use Data::Dumper;
# warn Dumper \%INC;
# exit;

our ($os,$mwd,$mName,$basePath,$slash);
BEGIN {
	($mwd,$mName) = (__FILE__ =~ /(.*)[\\|\/]([^\\|\/]*$)/); # module working directory
	$os = $^O;
	$slash = '/';
	if($os eq "MSWin32") { # include the needed libs for given OS
		$slash = '\\';
		require Win32::Console::ANSI; # Give color to the script output
		require Term::ANSIScreen; # Give color to the script output
	}
	$basePath = "$mwd${slash}..";
	# Add these paths to the end of the search array. NOTE: use lib adds the beginning.
	$INC[++$#INC] = "$basePath${slash}lib"; # perl libs/mods
}

our $logger;
###############################################################################################
# Do not use Logger for this one sub. This one is used to read files before logger is setup:
sub readDynamicConfigPre { # Read in configuration files and return hash
	# Read config like:
	#   path = <%basePath%>/old_wrfems/runs/co/static/ 
	
	my ($configFile,$infoRef) = @_;
	my %info;
	
	my $fh = new IO::File;
	open($fh,'<',$configFile) || croak "Can't open $configFile : $!";
	
	# Make first list of vars that are simple and will be used to fill in template vars like: <% var %>
	while(<$fh>) {
		next if /^#.*/; # Skip lines that start with #
		next if /^(\s)*$/;	# skip blank lines
		if(/^(\S+)(\s+)?(\=|\:)\s+(.*)$/) {
			$info{$1} = $4;
		}
	}
	seek($fh, 0, 0) || die "Cannot seek on file $configFile: $!"; # rewind file pointer
	
	if(defined($infoRef)) {
		%info = (%info,%{$infoRef});
	}
	
	my $lastKey;
	while(<$fh>) {
		next if /^#.*/; # Skip lines that start with #
		next if /^(\s)*$/;	# skip blank lines
		s/(.*?)(:?\s+?\#)[^\#]*$/$1/; # get rid of the commits
		s/[\r\n]$//; # Remove those end of line characters

		foreach my $key (keys %info) {
			s/<\%$key\%>/$info{$key}/g;
		}
		if(/^(\S+)(\s+)?(\=|\:)\s+(.*)/) {
			my ($name,$val) = ($1,$4);
			$val =~ s/\s+$//;
			$info{$name} = "$val";
			$lastKey = $name;
		} elsif(/^\s+([\S\ ]+)/) { # grab lines that start with spaces and have some contect after those spaces
			my $val = $1;
			$val =~ s/\s+$//g; # remove spaces at the end of the line
			$info{$lastKey} .= " $val";
		}
	}
	close($fh);
	
	return \%info;
}

###############################################################################################

sub readConfig { # Read in configuration files and return hash
	# Read config like:
	# varname = config info param

	my ($configFile) = @_;
	$logger->trace("Given ($configFile)");
	my %info;

	my $fh = new IO::File;
	open($fh,'<',$configFile) || $logger->logcroak("Can't open $configFile : $!");
	my $lastKey;
	while(<$fh>) {
		next if /^#.*/; # Skip lines that start with #
		s/(.*?)(\s+?\#)[^\#]*$/$1/; # get rid of the commits
		s/[\r\n]$//; # Remove those end of line characters

		if(/^(\S+)(\s+)?(\=|\:)\s+(.*)/) {
			my ($name,$val) = ($1,$4);
			$val =~ s/\s+$//;
			if(defined($info{$name})) {
				$logger->warn("Variable already defined '$name'");
			}
			$info{$name} = "$val";
			$lastKey = $name;
		} elsif(/^\s+([\S\ ]+)/) { # grab lines that start with spaces and have some contect after those spaces
			my $val = $1;
			$val =~ s/\s+$//g; # remove spaces at the end of the line
			$info{$lastKey} .= " $val";
		}
	}
	close($fh);
	
	return \%info;
}

sub readConfigSimpleTab { # Read in configuration files and return hash
	# Read config like:
	# varname = config info param

	my ($configFile) = @_;
	$logger->trace("Given ($configFile)");
	my %info;

	my $fh = new IO::File;
	open($fh,'<',$configFile) || $logger->logcroak("Can't open $configFile : $!");
	my $group;
	while(<$fh>) {
		next if /^#.*/; # Skip lines that start with #
		s/[\r\n]$//; # Remove those end of line characters

		if(/^(\S+)/) {
			$group = $1;
		} elsif(/^\s+([\S\ ]+)/) { # grab lines that start with spaces and have some contect after those spaces
			my $val = $1;
			$val =~ s/\s+$//g; # remove spaces at the end of the line
			$info{$group}{$val} = 1;
		}
	}
	close($fh);
	
	return \%info;
}

sub readTpl { # Read in template configuration files and return hash
	# Read config like:
	# varname = config info param

	my ($configFile) = @_;
	$logger->trace("Given ($configFile)");
	my %info;

	my $fh = new IO::File;
	open($fh,'<',$configFile) || $logger->logcroak("Can't open $configFile : $!");
	my $lastKey;
	my $group;
	while(<$fh>) {
		next if /^#.*/; # Skip lines that start with #
		s/[\r\n]$//; # Remove those end of line characters

		if(/^\&(\S+)/) {
			$group = $1;
		} elsif(/(\S+)(\s+)?(\=|\:)\s+(.*)/) {
			my ($name,$val) = ($1,$4);
			$val =~ s/\s+$//;
			$info{$group}{$name} = "$val";
			$lastKey = $name;
		} elsif(/^\s+([\S\ ]+)/) { # grab lines that start with spaces and have some contect after those spaces
			my $val = $1;
			$val =~ s/\s+$//g; # remove spaces at the end of the line
			$info{$group}{$lastKey} .= " $val";
		}
	}
	close($fh);
	
	return \%info;
}

sub readDynamicTpl { # Read in configuration files and return hash
	# Read config like:
	#   path = <%basePath%>/old_wrfems/runs/co/static/ 
	
	my ($configFile,$infoRef) = @_;
	$logger->trace("Given ($configFile,$infoRef)");
	my %info;
	
	my @lines;
	my $fh = new IO::File;
	open($fh,'<',$configFile) || $logger->logcroak("Can't open $configFile : $!");
	my $lastKey;
	while(my $line = <$fh>) {
		next if ($line =~ /^#.*/); # Skip lines that start with #
		next if($line =~ /^(\s)*$/); # blank line
		$line =~ s/(.*?)(\s+?\#)[^\#]*$/$1/; # get rid of the commits

		foreach my $key (keys %{$infoRef}) {
			$line =~ s/<\%$key\%>/$$infoRef{$key}/g;
		}
		$line =~ s/[\n\r]$//; # delete tailing end line character
		
		if($line =~ /<\%(.*?)\%>/) {
			$logger->info("Skipping line: '$line'");
		} else {
			$lines[++$#lines] = $line;
		}
	}
	close($fh);

	return \@lines;
}

sub readDynamicConfig { # Read in configuration files and return hash
	# Read config like:
	#   path = <%basePath%>/old_wrfems/runs/co/static/ 

	my ($configFile,$givenInfoRef,$keepNewline) = @_;
	$logger->trace("Given ($configFile,$givenInfoRef,$keepNewline)");
	my %info;

	my $fh = new IO::File;
	open($fh,'<',$configFile) || $logger->logcroak("Can't open $configFile : $!");

	# Make first list of vars that are simple and will be used to fill in template vars like: <% var %>
	while(<$fh>) {
		next if /^#.*/; # Skip lines that start with #
		next if /^(\s)*$/;	# skip blank lines
		s/(.*?)(:?\s+?\#)[^\#]*$/$1/; # get rid of the commits

		if(/^(\S+)(\s+)?(\=|\:)\s+(.*)$/) {
			$info{$1} = $4;
		}
	}
	seek($fh, 0, 0) || $logger->logcroak("Cannot seek on file $configFile: $!"); # rewind file pointer
	
	if(defined($givenInfoRef)) { # if user wants to inject some vars, lets do it here:
		foreach my $key (keys %{$givenInfoRef}) {
			$info{$key} = $$givenInfoRef{$key};
		}
	}

	my $lastKey;
	while(<$fh>) {
		next if /^#.*/; # Skip lines that start with #
		s/[\r\n]$//; # Remove those end of line characters
		s/(.*?)(:?\s+?\#)[^\#]*$/$1/; # get rid of the commits

		foreach my $key (keys %info) {
			s/<\%$key\%>/$info{$key}/g;
		}
		if(/^(\S+)(\s+)?(\=|\:)\s+(.*)/) {
			my ($name,$val) = ($1,$4);
			next if(defined($info{$name}) && $info{$name} !~ /<%.*%>/); # This will enable override with the given input
			$val =~ s/\s+$//;
			if(defined($keepNewline)) {
				$info{$name} = "$val\n";
			} else {
				$info{$name} = "$val";
			}
			$lastKey = $name;
		} elsif(/^\s+([\S\ ]+)/) { # grab lines that start with spaces and have some contect after those spaces
			my $val = $1;
			$val =~ s/\s+$//g; # remove spaces at the end of the line
			if(defined($keepNewline)) {
				$info{$lastKey} .= "$val\n";
			} else {
				$info{$lastKey} .= "$val";
			}
		}
	}
	close($fh);


	# Cut off the last newline from the data.
	foreach my $key (keys %info) {
		$info{$key} =~ s/\n+$//;
	}

	return \%info;
}

sub writeTpl { # Write the template
	my ($configFile,$lines) = @_;
	$logger->trace("Given ($configFile,$lines)");

	my $fh = new IO::File;
	open($fh,'>',$configFile) || $logger->logcroak("Can't open $configFile : $!");

	foreach my $line (@{$lines}) {
		print $fh "$line\n";
	}
	close($fh);

	return;
}

sub fileLog { # Write the template
	my ($file,$msg) = @_;

	my $fh = new IO::File;
	open($fh,'>>',$file) || $logger->logcroak("Can't open $file : $!");
		print $fh "$msg\n";
	close($fh);

	return;
}

sub createDir { # creates a directory according to given path 
	my ($dir) = @_;
	if(!-e $dir) {
		mkpath($dir);
		if(!-e $dir) {
			$logger->logcroak("failed to make the need dir '$dir");
		}
	}
	
	return;
}

sub readDir { # Given path, will return array of files
	my ($dir,$doNotSkipDotFile) = @_;
	if(!$dir) { $logger->logcroak("No dir given '$dir'"); }
	if(!-e $dir) { $logger->logcroak("Given dir doesn't exist '$dir'"); }

	my $dh = new IO::Dir;
	opendir($dh, $dir) || $logger->logcroak("Couldn't open $dir: $!.");
	my @files;
	while (my $file = readdir($dh)) {
		if(!$doNotSkipDotFile) {
			next if ($file =~ /^\./);
		}
		$files[++$#files] = $file;
	}
	closedir($dh);

	return @files;
}

sub readDirHash { # Given path, will return array of files
	my ($dir,$giveSize) = @_;
	if(!$dir) { $logger->logcroak("No dir given '$dir'"); }
	if(!-e $dir) { $logger->logcroak("Given dir doesn't exist '$dir'"); }

	my %list;
	
	my $dh = new IO::Dir;
	opendir($dh, $dir) || $logger->logcroak("Couldn't open $dir: $!.");
	while (my $file = readdir($dh)) {
		next if($file =~ /^\./);
		if(defined($giveSize)) {
			$list{$file} = stat("$dir${slash}$file")->size;
		} else {
			$list{$file} = 1;
		}
	}
	closedir($dh);

	return \%list;
}

sub deleteDir { # Recursive delete a directory and contents
	my ($dir) = @_;
	if(!$dir) { $logger->logcroak("Dir not given '$dir'"); }
	if(!-e $dir) { $logger->logcroak("Dir doesn't exist '$dir'"); }
	if($dir eq "/") { $logger->logcroak("Will not delete root '$dir'"); }

	rmtree($dir, 0, 1) || $logger->logcroak("rmtree error: $dir: $!");

	return;
}
###############################################################################################
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