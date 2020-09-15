package Log;
# Author:  Ryan Wilcox
# Description: This module is to setup logging for the calling scripts
#
# Example of use: 
#	our ($logObj,$logger) = Log->new('daemon',"$swd${slash}config${slash}log4perl.conf"); # logObj = my 'Log' lib, $logger = Log::Log4perl::Logger
# - OR -
#	our ($logObj,$logger) = Log->new; # logObj = my 'Log' lib, $logger = Log::Log4perl::Logger
my $version = '1.8';

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

	@ISA = ("Log::Log4perl"); # extend the current name space to also search in Log::Log4perl
	@EXPORT_OK = qw(info debug trace warn error fatal croak logcroak die);


}

use strict;
use Carp; # issue warnings from calling code.
use File::Path qw(make_path); # used to create the needed folder path for the log
use Log::Log4perl qw(:easy :no_extra_logdie_message); # Log4j implementation for Perl
use Util; # Basic lib utilities

our $logger;

our ($swd,$progName) = ($0 =~ /(.*)[\\|\/]([a-zA-Z0-9\.\-\_]+.pl)/);
our $configFolder = "${basePath}${slash}config${slash}"; # the location of the configs
###############################################################################################
sub new { # Create object 
	my ($proto,$type,$givenLogFile,$configPath) = @_;
	my $class = ref($proto) || $proto;
	my $self  = {};
	bless ($self,$class);

	# "type" can be one of the following:
	# default is to print to the log and the screen
	# logOnly
	# 	daemon
	# 	web
	##
	# screenOnly
	# 	test

	my $env; # don't use this variable unless it is detected that it is needed
	if(defined($configPath)) {
		Log::Log4perl::init($configPath);
	} elsif(defined($givenLogFile)) {
		$self->setupLogFile($givenLogFile);
	} elsif($type eq 'test' || $type eq 'LogOnly') {
		# We don't need to setup a log file if logging is only going to teh screen
	}else { # if the user didn't give a log file to use lets read the env config for the log dir
		$env = &Util::readDynamicConfigPre("${configFolder}environment.cfg");

		if(!defined($$env{loggerDir})) {
			croak "Error: missing need var from main config 'loggerDir'\n";
		}
		
		$self->setupLogFile("$$env{loggerDir}${slash}${progName}.log");
	}
	
	if(defined($type)) {
		$self->{type} = $type;
	}

	$logger = Log::Log4perl->get_logger($progName);

	if(defined($env) && defined($$env{loggerLevel})) { # If there is a level given in the env config file lets use this
		if($$env{loggerLevel} !~ /^trace|debug|info|warn|error|fatal$/i) {
			croak "Error: Given logging level doesn't match of the needed cases 'trace, debug, info, warn, error, fatal'\n";
		}
		$self->useLevel(uc($$env{loggerLevel}));
	} else {
		$self->useLevel('INFO');
	}

	return $self; # Return the local handler along with the logger handler
}

sub DESTROY {
	my $self = shift;

	undef $logger;
	
	return;
}

sub debug { # Turn on debugging for this module. Do Not use this if you are running from a CGI script, this prints to standard out
	my ($self) = @_;

	if(!defined($self->{debug})) {
		print "Turnning on Log debug!\n";
		$self->{debug} = 1;
	} elsif($self->{debug} == 0) {
		print "Turnning on Log debug!\n";
		$self->{debug} = 1;
	}

	return;
}

sub setupLogFile { # setup the given logfile for use
	my ($self,$logFile) = @_;
	
	if(!defined($logFile)) {
		croak("Error: Not given a log file to setup");
	}

	my ($path,$file) = ($logFile =~ /(.*?)([^\/|\\]*$)/);
	# print "#$logFile# ($path,$file)\n";
	
	if(!defined($path) || $path eq '') {
		croak("Error: Given log file needs to have full path. Example (/opt/project/daemon.log)");
	}
	if(!-d $path) {
		if($self->{debug} == 1) { print "Making needed logging dir before logging libs can work!\n" };
		make_path($path);
		if(!-d $path) {
			croak("Error: Failed to create needed logging directory '$path'");
		}
	}
	
	if(!-e $logFile) { # lets try and create the log file given
		$self->createEmptyFile($logFile);
		if(!-e $logFile) {
			croak("Error: Failed to create needed log file '$logFile'");
		}
	}
	
	$self->{logFile} = $logFile;
	return;
}

sub setup { # Will setup logging for all higher level libs and modules used in the user script
	my ($self) = @_;

	if(!defined($logger)) {
		croak("Error: Logger interface not setup.");
	}

	my $libPath = $mwd; # This should be the full path to the libs, like: /home/wrf/nms/domains/co_prod/run/2012071216/../../../../scripts/lib/
	$libPath =~ s|([\:\\])|\\$1|g; # don't regx these
	$libPath .= $slash; # add the slash so that path finding can work below
	$libPath =~ s|^\.$slash||; # we want to cut off the starting dot if the user is running script from the same path as the script

	# use Data::Dumper;
	# print Dumper(\%INC);
	# print "#$swd#$libPath#\n";
	# exit;
	
	foreach my $mod (keys %INC) {	
		# We want to automatically turn debugging on for created libs
		# We also don't want to touch libs from libsite because they are not apart of this framework (just the lib folder)
		if($INC{$mod} =~ /^${libPath}/) { # will find all libs that are in the same path as Log.pm
			my $packageName = ($mod =~ /^(\w+)/)[0];
			next if($packageName eq 'Log'); # don't need to setup logging for this module again.
			if($packageName->can('logger')) {
				if($self->{debug} == 1) { print "Enabling loging for '$packageName'\n" };
				
				$logger->trace("Enabling loging for '$packageName'");
				$packageName->logger($logger);
			} else {
			
			}
		}
	}

	return $logger;
}

sub useLevel { # Chanage the logging to use TRACE level
	my ($self,$level) = @_;

	if(!defined($self->{logFile}) && !($self->{type} eq 'test' || $self->{type} eq 'logOnly')) {
		croak("Error: Log file is not setup");
	}

	if($level !~ /FATAL|ERROR|WARN|INFO|DEBUG|TRACE/) {
		croak("Error: Not given Logging level to use.");
	}
	# if($level =~ /DEBUG|TRACE/) {
		# $logger->info("Changing logging level to '$level'");
	# }

	$self->{level} = $level;

	my $category = "$level, Screen, Logfile";
	if($self->{type} eq 'daemon' || $self->{type} eq 'web' || $self->{type} eq 'logOnly') { # For daemon code we don't need to print to the screen
		$category = "$level, Logfile";
	} elsif($self->{type} eq 'test' || $self->{type} eq 'screenOnly')  {
		$category = "$level, Screen";
	}
	
	# Dynamically use log4perl to use synergy vars
	my $logConfig = qq~ 
		log4perl.category  					= $category
		log4perl.appender.Logfile			= Log::Log4perl::Appender::File
		log4perl.appender.Logfile.filename	= $self->{logFile}
		log4perl.appender.Logfile.layout	= PatternLayout
		log4perl.appender.Logfile.layout.ConversionPattern = %d %-5p %M (%P) %L> %m %n
		log4perl.appender.Screen			= Log::Log4perl::Appender::ScreenColoredLevels
		log4perl.appender.Screen.layout		= Log::Log4perl::Layout::PatternLayout
		log4perl.appender.Screen.layout.ConversionPattern = %d %-5p %M (%P) %m %n
	~;

	$self->useConfig($logConfig);

	return;
}

sub useConfig { # general fun to setup logger with given config settings
	my ($self,$logConfig) = @_;

	Log::Log4perl::init(\$logConfig); # passed as a reference to init()
	$logger = Log::Log4perl::get_logger();
	$logger->debug("logging setup!");

	return;
}

sub createEmptyFile {
	my ($self,$logFile) = @_;

	if(!defined($logFile)) {
		croak("Error: Not given a log file to createEmptyFile");
	}

	eval {
		open my $fh, '>', $logFile || croak "Cannot create $logFile: $!\n";
		close $fh || croak "Cannot close $logFile: $!\n";
	};

	return $@;
}

# The follwing code is needed for other modules that want to use this logging method
# sub logger { # General logger init code that is used in each mod that want logging to be setup
	# my ($self) = @_;
	# my ($givenLogger) = @_;
	# if(!defined($givenLogger)) {
		# $logger->logcroak("This module needs to be given a logging interface");
	# }
	
	# # set the local logger to the one given
	# $logger = $givenLogger;
	
	# return;
# }
###############################################################################################
1; # must return somthing!