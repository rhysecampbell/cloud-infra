#!/usr/bin/perl
# Author:  Ryan Wilcox
# Description: This will load the needed templates for the nwp site

our $version = '2.1.0.5';

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
use Template; # libtemplate-perl
use Util; # Basic lib utilities
use Log; # Setup logging for used mods/libs  liblog-log4perl-perl

$CGI::Simple::POST_MAX = 1024;       # max upload via post default 100kB
$CGI::Simple::DISABLE_UPLOADS = 1;   # Disable uploads

my $logObj = Log->new('web'); # web= prints log message only to the log
my $logger = $logObj->setup; # Will setup logging for all higher level libs and modules used in this script

our $configFolder = "$basePath${slash}config${slash}"; # the location of the configs
our $env = &Util::readDynamicConfig("${configFolder}environment.cfg");
our $cgi = new CGI::Simple;
$cgi->parse_query_string;  # add $ENV{'QUERY_STRING'} data to our $q object

our %input;
for my $key ($cgi->param()) { # Convert all web form inputs into a hash and filter bad input
	my $value = join ',',$cgi->param($key); # Create comma list if given array data (even if data isn't an array)
	$value =~tr#[a-zA-Z0-9\ \t\n\.\,\/\\\;\:\[\]\{\}\(\)\!\#\^\<\>\=\-\_\|\n]# #c; # We only want these chars
	$value =~ s#(\.\.)##g; # Remove some other stuff that isn't needed, hackers! dir traversal
	$value =~ s#^\s+|\s+$##g; # Tailing and beginning spaces
	if($value eq "" || $value =~ /^\s*$/) { next; } # If the input's value is blank, then skip.
	$logger->trace("Input: $key: '$value'"); # Log the data returned form user (debug is great!)
	$input{$key} = $value;
}
###############################################################################################
if(!defined($$env{templateDir})) {
	$logger->logcroak("Needed ENV variable doesn't exist 'templateDir'");
}

# This will enable the non minimized javascript files and few other options.
my $debugJavascript = 0;
if($$env{debugJavascript} == 1) {
	$debugJavascript = 1;
	$logger->info("javascript debugging enabled");
}

my $tt = Template->new({ # Create template object
	INCLUDE_PATH => "$basePath${slash}$$env{templateDir}",
	INTERPOLATE  => 0,
    PRE_CHOMP  => 1, # lets try and minimize the amount of white space getting added by using Template Toolkit
}) || $logger->logcroak($Template::ERROR);

my $vars = {
	debug => $debugJavascript,
	version => $version,
};

print "Content-Type: text/html; charset=utf-8\n\n";
if($input{'page'} eq 'userManagement') {
	$tt->process('userManagement.html', $vars) || $logger->logcroak($tt->error());
} elsif($input{'page'} eq 'stationAssociation') {
	$tt->process('stationAssociation.html', $vars) || $logger->logcroak($tt->error());
} elsif($input{'page'} eq 'metarInfo') {
	$tt->process('metarInfo.html', $vars) || $logger->logcroak($tt->error());
} elsif($input{'page'} eq 'metarAssociation') {
	$tt->process('metarAssociation.html', $vars) || $logger->logcroak($tt->error());
} elsif($input{'page'} eq 'roleManagement') {
	$tt->process('roleManagement.html', $vars) || $logger->logcroak($tt->error());
} else {
	$tt->process('stationInfo.html', $vars) || $logger->logcroak($tt->error());
}

###############################################################################################

