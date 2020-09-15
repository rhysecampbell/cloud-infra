#!/usr/bin/perl

$debugLevel=1;

use File::Path qw(remove_tree);
use File::Copy;

$workPath="/home/ldm/var/data/surface/work";

# list of METAR paths
open (PATHS,"$workPath/metarPaths.txt");
@paths=<PATHS>;
close PATHS;

foreach $metarpath (@paths) {
$metarpath =~ m/(\S{2}$)/;
$country=$1;
chomp $country;

# remove previous link
unlink ("$workPath/python/data");

# create new link
chomp $metarpath;
symlink ($metarpath, "$workPath/python/data");


# python METAR creation from raw data:

# get rid of previous data
remove_tree("$workPath/python/outputdir",{keep_root=>1});
remove_tree("$workPath/carved",{keep_root=>1});

system ("$workPath/python/collectivebuster.py");


# carve up the data files into smaller chunks, so sendcc doesn't die
system ("$workPath/fileSlicer.ksh");


# do the XML creation
system ("$workPath/metar2xml.pl");
system ("$workPath/metar2xml.new.pl");

if ($debugLevel) {
	print "Running METAR stats for $country\n";
	}

# count the METARs for statistics
system ("$workPath/counter.pl $country");


}

# make a copy of all files to be sendcc, for 2nd sendcc process
#for $file ( <$workPath/xml/*> ) {
#	copy( $file, "$workPath/xml-copy" ) or warn "Cannot copy $file: $!";
#}


system ("/home/vaisala/bin/sendcc -c metar-prod.conf");
system ("/home/vaisala/bin/sendcc -c metar-prod-skyConditions.conf");
