#!/usr/bin/env python

import os
import web

db = web.database(dbn='postgres', database='cloud', host='192.168.x.100', port=5432, user='', password='')

stations = db.select('oe.station_identity', what='xml_target_name,image1_url', where='image1_url IS NOT NULL')

sensitive_files = os.listdir('/var/www/html/images/')
lower_files = [x.lower() for x in sensitive_files]

for station in stations:
    try:
        index = lower_files.index(station.image1_url.lower())
    except ValueError:
        continue
    real_case = sensitive_files[index]
    db.update('oe.station_identity', where='xml_target_name=$target', image1_url=real_case, vars={'target': station.xml_target_name})
