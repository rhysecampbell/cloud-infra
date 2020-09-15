scripts:

	~/scripts/
		# process the Triton Obs, multi process, with wrapper to call them, and finally runs sendcc
		tritonAPI-Obs.sh
		tritonAPI-Obs-multi.pl

		# process the Triton sysEvents.  Single process.  Runs sendcc.
		tritonAPI-SE-lastTrack.pl

		# checks for lat/lon changes, updates db and emails when they are observed
		locationCheckChange.pl
		sendEmail

Directories:
	~/scripts/		# contains the scripts
	~/lastEvents		# contains list of files containing info about the site latest sysEvent times
	~/lastUpdates		# contains list of files containing info about the site latest obs times
	~/sendcc-completed	# sendcc place to dump files after they're sent
	~/status-xml		# sysEvent storage, before sendcc picks them up
	~/xml-processed		# obs storage, before sendcc picks them up
	~/conf			# sendcc triton.conf (obs), triton-status.conf (events), and sample cron.


triton.cron		# contains sample of cron
fields-lookup.txt	# contains lookup table for DQM
fields-lookup.txt.zero	# contains lookup table for DQM with ".0" after each name, when we're ready

* note, still need to implement file cleanup for ~/sendcc-completed ; it grows quite large quickly
