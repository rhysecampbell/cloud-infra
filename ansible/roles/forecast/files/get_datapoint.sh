# sript to get datapoint data and load forcastDB March 2014 BJT

# get data
/usr/bin/curl -o /home/data/fc2obs/landing/fulldump.xml "http://datapoint.metoffice.gov.uk/public/data/val/wxfcs/all/xml/all?res=3hourly&key=3bc8904a-13e8-4faa-95fe-5821e4bef432"

# parse data and split output files
/usr/local/bin/fc2obs -c datapoint.conf -b

# upload to DB - *MUST* equal fc2obs configured output 
/usr/local/bin/sendcc -c fcast/fcast_01.conf -b
/usr/local/bin/sendcc -c fcast/fcast_02.conf -b
/usr/local/bin/sendcc -c fcast/fcast_03.conf -b
/usr/local/bin/sendcc -c fcast/fcast_04.conf -b
/usr/local/bin/sendcc -c fcast/fcast_05.conf -b
/usr/local/bin/sendcc -c fcast/fcast_06.conf -b
/usr/local/bin/sendcc -c fcast/fcast_07.conf -b
/usr/local/bin/sendcc -c fcast/fcast_08.conf -b
/usr/local/bin/sendcc -c fcast/fcast_09.conf -b
/usr/local/bin/sendcc -c fcast/fcast_10.conf -b

