#!/usr/bin/env python

import argparse
import xml.etree.cElementTree as ET

from datetime import datetime, timedelta
from requests import codes as requests_codes
from requests_futures.sessions import FuturesSession
from xml.etree import ElementTree as ET

parser = argparse.ArgumentParser(description='Fetch dqm images')
parser.add_argument('-H', '--host', metavar='ADDRESS', required=True)
args = parser.parse_args()

namespaces = {'SOAP-ENV': 'http://schemas.xmlsoap.org/soap/envelope/',
              'SOAP-ENC': 'http://schemas.xmlsoap.org/soap/encoding/',
              'xsi': 'http://www.w3.org/2001/XMLSchema-instance',
              'xsd': 'http://www.w3.org/2001/XMLSchema',
              'vai4': 'http://www.vaisala.com/schema/ice/iceMsgCommon/v1',
              'vai1': 'http://www.vaisala.com/wsdl/ice/uploadIceObservation/v2',
              'vai3': 'http://www.vaisala.com/schema/ice/obsMsg/v2',
              }

try:
    register_namespace = ET.register_namespace
except AttributeError:
    def register_namespace(prefix, uri):
        ET._namespace_map[uri] = prefix

for prefix, uri in namespaces.iteritems():
    register_namespace(prefix, uri)


class ObsV2XML:
    def __init__(self):
        self.observation = ET.Element("{%s}observation" % namespaces['vai3'],
                                      attrib={'version': '2.0',
                                              'fastTrackQC': 'false'})
        self.instances = {}
        self.resultOfs = {}

    def add_station(self, target):
        # target = (idType, id)
        self.instances[target] = ET.SubElement(self.observation,
                                               "{%s}instance" % namespaces['vai3'])
        targettag = ET.SubElement(self.instances[target],
                                  "{%s}target" % namespaces['vai3'])
        idtypetag = ET.SubElement(targettag, "{%s}idType" % namespaces['vai4'])
        idtypetag.text = target[0]
        idtag = ET.SubElement(targettag, "{%s}id" % namespaces['vai4'])
        idtag.text = target[1]


    def add_timestamp(self, target, timestamp):
        if (target,timestamp) not in self.resultOfs:
            self.resultOfs[(target, timestamp)] = ET.SubElement(self.instances[target],
                                                                "{%s}resultOf" % namespaces['vai3'],
                                                                attrib={'codespace': 'NTCIP',
                                                                        'timestamp': timestamp,
                                                                        'reason': 'scheduled',
                                                                        'version': '0.0.1'})

    def add_value(self, target, timestamp, code, value, quality="1"):
        self.add_timestamp(target, timestamp)
        tag = ET.SubElement(self.resultOfs[(target, timestamp)],
                            "{%s}value" % namespaces['vai3'],
                            attrib={'code': code,
                                    'quality': quality})
        tag.text = str(value)

    def xml(self):
        return ET.tostring(self.observation, encoding="UTF-8")

now = datetime.utcnow()
roundednow = now - timedelta(seconds=(now.second + 60), microseconds=now.microsecond)

session = FuturesSession(max_workers=10)
r = session.get('http://%s/api/v1/dqmData/values?geo=90,-180,-90,180&exactTime=%s' % (args.host, roundednow.strftime('%Y%m%dT%H%M%S')), auth=('demo', 'demovai'), verify=False).result()
meta = session.get('http://%s/api/v1/dqmData/meta?geo=90,-180,-90,180&period=P5M&queryMode=insertionTime' % args.host, auth=('demo', 'demovai'), verify=False).result()
stations = {}
for station in meta.json()['metaData']:
    if 'stationnId' in station:
        stn_id = station['stationnId']
    else:
        stn_id = station['stationId']
    stations[stn_id] = station['xmlTargetName']

history = []

for observation in r.json()['observations']:
    stationId = observation[u'stationId']
    stationName = observation[u'stationName']
    xml_target_name = stations[stationId]
    target = ('stationFullName', xml_target_name)
    obsv2 = ObsV2XML()
    obsv2.add_station(target)
    for dataset in observation['dataSet']:
        timestamp = dataset['time']
        if timestamp[10] == ' ':
            timestamp = timestamp.replace(' ', 'T')
        for record in dataset['values']:
            symbol = record['symbol']
            if symbol.startswith(('essIce','essAvgWindS','essSpotWindS','essMaxWindGustS','essAirT','essWetbulbT','essDewpointT','essMaxT','essMinT','spectroRelativeHumidity','spectroSurfaceTemp','essSurfaceTemp','essSurfaceFreeze','essVisibility.','essAtmosphericPressure.','spectroAirTemp','essSubSurfaceTemperature','essPavementTemperature', 'spectroSurfaceFrictionIndex')):
                multiplier = 10
            elif symbol.startswith(('spectroSurfaceIceLayer','spectroSurfaceWaterLayer','spectroSurfaceSnowLayer')):
                multiplier = 100
            else:
                multiplier = 1
            value = record['nvalue']
            if value is not None:
                value = value*multiplier
            if record['qcFailed'] > 0:
                quality = "-100"
            else:
                quality = "1"
            obsv2.add_value(target, timestamp, symbol, value, quality)
    payload = obsv2.xml().replace("<?xml version='1.0' encoding='UTF-8'?>", '')
    payload = """<?xml version="1.0" encoding="UTF-8"?>
    <SOAP-ENV:Envelope xmlns:SOAP-ENV="http://schemas.xmlsoap.org/soap/envelope/" xmlns:SOAP-ENC="http://schemas.xmlsoap.org/soap/encoding/" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns:xsd="http://www.w3.org/2001/XMLSchema" xmlns:vai4="http://www.vaisala.com/schema/ice/iceMsgCommon/v1" xmlns:vai1="http://www.vaisala.com/wsdl/ice/uploadIceObservation/v2" xmlns:vai3="http://www.vaisala.com/schema/ice/obsMsg/v2"><SOAP-ENV:Body>%s</SOAP-ENV:Body></SOAP-ENV:Envelope>""" % payload
    history.append((session.post('http://db.vaicld.com:40001', data=payload), timestamp, stationId, stationName))

for future, timestamp, stationId, stationName in history:
    r = future.result()
    if r.status_code == requests_codes.ok:
        tree = ET.fromstring(r.text)
        status = tree.find('.//{http://www.vaisala.com/schema/ice/iceMsgCommon/v1}status').text
        message = tree.find('.//{http://www.vaisala.com/schema/ice/iceMsgCommon/v1}text').text.replace('\n', ' | ')
        print "OK", timestamp, stationId, stationName, status, message
    else:
        print "ERROR", timestamp, stationId, stationName, r.text

# vim: tabstop=8 expandtab shiftwidth=4 softtabstop=4
