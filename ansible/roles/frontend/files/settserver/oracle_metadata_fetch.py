#!/usr/bin/env python

import logging

from suds.client import Client
from suds import WebFault

client = Client("http://haproxy.dsbir.vaisala.com:8080/RdsVisualisationV3Service/RdsVisualisationV3?wsdl")

sessionid = client.service.logon("username", "password")

target_name = raw_input("Enter the target name: ")

def fetch_metadata(target_name, idType='stationAlias'):
    return client.service.getStationGroupMetaDataForTarget(sessionid, {'idType': idType, 'id': target_name})

try:
    meta = fetch_metadata(target_name)
except WebFault:
    try:
        meta = fetch_metadata(target_name, 'hardwareSerialNumber')
    except WebFault:
        print "Nothing found..."
        meta = None

if meta:
    name = meta.organisationInstance[0].station[0].name
    try:
        lat = meta.organisationInstance[0].station[0].geoPosition._x
        lon = meta.organisationInstance[0].station[0].geoPosition._y
        alt = meta.organisationInstance[0].station[0].geoPosition._z
        print "%s: (%s, %s, %s)" % (name, lat, lon, alt)
    except AttributeError:
        print "%s: ( , , )" % name

client.service.logoff(sessionid, )
