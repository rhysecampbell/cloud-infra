#!/usr/bin/perl
# Author:  Ryan Wilcox
# Description: simple tool to convert json data

# Needed data with Rhys help found at: https://github.com/lukes/ISO-3166-Countries-with-Regional-Codes

use strict;
use Carp; # Issue warnings from calling code
use IO::File; # Use file handles with scope
use JSON; # libjson-perl

my $inputJSONfile = shift(@ARGV);
my $outputJSONfile = 'country_codes.json';
my $outputJSONfileSmall = 'country_codes_small.json';

if(!defined($inputJSONfile) || !-e $inputJSONfile) {
	die "The given file doesn't exist";
}


my $jsonInput;
my $fh = new IO::File;
open($fh,'<',$inputJSONfile) || croak("Can't open $inputJSONfile : $!");
	$jsonInput = <$fh>;
close($fh);
undef($fh);

my $json = decode_json($jsonInput);

my @dataOut;
my %dataOutSmall;
my $i = 0;

$dataOut[$i]{name} = "Blank Value";
$dataOut[$i]{id} = 'blank';
$i = 3; # lets skip 2 so we can have room for the GB and US

foreach my $element (@{$json}) {
	print "i:$i #$$element{name}#$$element{'alpha-2'}#\n";
	if(defined($$element{'name'}) && defined($$element{'alpha-2'})) {
		
		# Remove white spaces from both sides of the string
		#$$element{'name'} =~ s/^\s*(.*?)\s*$/$1/;
		#$$element{'alpha-2'} =~ s/^\s*(.*?)\s*$/$1/;

		if($$element{'alpha-2'} eq 'US') {
			$dataOut[1]{name} = "$$element{'name'} ($$element{'alpha-2'})";
			$dataOut[1]{id} = $$element{'alpha-2'};
		} elsif($$element{'alpha-2'} eq 'GB') {
			$dataOut[2]{name} = "$$element{'name'} ($$element{'alpha-2'})";
			$dataOut[2]{id} = $$element{'alpha-2'};
		} else {
			$dataOut[$i]{name} = "$$element{'name'} ($$element{'alpha-2'})";
			$dataOut[$i]{id} = $$element{'alpha-2'};
			
			$i++;
		}
		$dataOutSmall{"$$element{'alpha-2'}"} = "$$element{'name'} ($$element{'alpha-2'})";
	}
	
}



# This will help the website display the most common values at the top of the large list
my $smallJSON = '{';
$smallJSON .= "\"blank\":\"Blank Value\",";
$smallJSON .= "\"US\":\"$dataOutSmall{US}\",";
$smallJSON .= "\"GB\":\"$dataOutSmall{GB}\",";
foreach my $key (sort keys %dataOutSmall) {
	if($key ne 'UK' && $key ne 'GB') {
		$smallJSON .= "\"$key\":\"$dataOutSmall{$key}\",";
	}
}
chop($smallJSON); # cut the last "," off the end
$smallJSON .= '}';


my $json = JSON->new();
$json = $json->canonical(1);
my $jsonOutput = $json->utf8->encode(\@dataOut);




my $fh = new IO::File;
open($fh,'>:encoding(UTF-8)',$outputJSONfile) || croak("Can't write $outputJSONfile : $!");
	print {$fh} $jsonOutput;
close($fh);

my $fh = new IO::File;
open($fh,'>:encoding(UTF-8)',$outputJSONfileSmall) || croak("Can't write $outputJSONfileSmall : $!");
	print {$fh} $smallJSON;
close($fh);
