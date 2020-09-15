#!/usr/bin/env python

import argparse
import requests
from os import path
from base64 import b64decode
from datetime import datetime, timedelta

parser = argparse.ArgumentParser(description='Fetch dqm images')
parser.add_argument('-H', '--host', metavar='ADDRESS', required=True)
parser.add_argument('-o', '--output-directory', metavar='DIRECTORY', required=True)
args = parser.parse_args()

now = datetime.utcnow()
roundednow = now - timedelta(seconds=(now.second + 60), microseconds=now.microsecond)

r = requests.get('http://%s/api/v1/dqmImage/values?geo=90,-180,-90,180&exactTime=%s' % (args.host, roundednow.strftime('%Y%m%dT%H%M%S')), auth=('demo', 'demovai'), verify=False)

meta = requests.get('http://%s/api/v1/dqmImage/meta?geo=90,-180,-90,180&period=P5M&queryMode=insertionTime' % args.host, auth=('demo', 'demovai'), verify=False)
cameras = {}
for station in meta.json()['metaData']:
    stn_id = station['stationId']
    if 'cameraData' not in station:
        continue
    for camera in station['cameraData']:
        i = (stn_id, camera['cameraNo'])
        cameras[i] = camera['imageTargetName']

for observation in r.json()['images']:
    stationId = observation[u'stationId']
    for dataset in observation['dataSet']:
        for camera in dataset['values']:
            i = (stationId, camera['cameraNo'])
            if i not in cameras:
                print "Skipping", i
                continue
            filename = cameras[i]
            filepath = path.join(args.output_directory, filename)
            with open(filepath, 'wb') as file:
                file.write(b64decode(camera['image']))
                print "written", filename

# vim: tabstop=8 expandtab shiftwidth=4 softtabstop=4
