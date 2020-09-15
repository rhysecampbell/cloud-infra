#!/usr/bin/env python
#FORMAT PYTHON

import web

try:
    from xml.etree.cElementTree import Element, SubElement, tostring
except ImportError:
    try:
        # pylint: disable=F0401
        from cElementTree import Element, SubElement, tostring
    except ImportError:
        try:
            from xml.etree.ElementTree import Element, SubElement, tostring
        except ImportError:
            # pylint: disable=F0401,E0611
            from elementtree.ElementTree import Element, SubElement, tostring

from common import InjectingFilter, dbconfig, dbprinting

db = web.database(**dbconfig)
db.printing = dbprinting



qttsensors = {'T': ('atmospheric', 'airtemperature', 100),
              #'P': '',
              'RH': ('atmospheric', 'relativehumidity', 1),
              'VI': ('atmospheric', 'visibilitymeters', 10),
              'PRA24H': ('atmospheric', 'precipitation24hour', 10),
              'PRA12H': ('atmospheric', 'precipitationtwelvehour', 10),
              'PRA1H': ('atmospheric', 'precipitationonehour', 10),
              'PRA3H': ('atmospheric', 'precipitationthreehour', 10),
              'PRA6H': ('atmospheric', 'precipitationsixhour', 10),
              'TD': ('atmospheric', 'dewpointtemperature', 100),
              'WD': ('atmospheric', 'avgwinddirection', 10),
              'WSM': ('atmospheric', 'maxwindgustspeed', 10),
              'WDM': ('atmospheric', 'maxwindgustdirection', 1),
              'WS': ('atmospheric', 'avgwindspeed', 10),
              'RD': ('atmospheric', 'precipyesno', 1),
              'ST': ('pavement', 'surfacestatus', 1),
              'TS': ('pavement', 'surfacetemperature', 100),
              'TS': ('pavement', 'surfacefreezepoint', 100),
              'CS': ('pavement', 'conductivity', 1),
              'TB': ('subsurface', 'temperature', 100),
              }

qttenums= {'ST': {0: 2,
                  1: 1,
                  2: 2,
                  4: 3,
                  5: 4,
                  6: 5,
                  7: 6,
                  8: 13,
                  9: 9,
                  14: 11,
                  15: 12,
                  16: 14,
                  19: 7,
                  20: 8,
                  },
           'RD': {0: 2,
                  1: 1,
                  2: 3},
           'RS': {0: 1,
                  1: 3,
                  2: 3,
                  4: 4,
                  5: 5,
                  6: 6,
                  7: 7,
                  8: 8,
                  9: 9,},
           'PW': {40: 4,
                  41: 5,
                  42: 6,
                  64: 13,
                  65: 14,
                  66: 15,
                  71: 7,
                  72: 8,
                  73: 9,
                  81: 10,
                  82: 11,
                  83: 12,},
           }

def get_qtt_id(vmdb_id):
    """Return qtt_id from exportws.qttids"""
    return None # FIXME: qttids table
    try:
        return db.select('exportws.qttids',
                         where="vmdb_id=$vmdb_id",
                         vars={'vmdb_id': vmdb_id},
                         )[0].qtt_id
    except IndexError:
        return None


class QttNtcipObsXML:
    def __init__(self, rows):
        self.root = Element("qtt.data.exchange")
        self.root.attrib["xmlns:xsi"] = "http://www.w3.org/2001/XMLSchema-instance"
        self.root.attrib["xmlns:xsd"] = "http://www.w3.org/2001/XMLSchema"
        self.instance = {}
        for row in rows:
            self.process_row(row)

    def process_row(self, row):
        if not row.vmdb_id in self.instance.keys():
            self.add_station(row.vmdb_id, row.station_name)
        try:
            group, data_symbol, scale = qttsensors[row.data_symbol]
        except KeyError:
            return
        if row.data_symbol in qttenums.keys():
            try:
                value = str(qttenums[row.data_symbol][row.data_value])
            except KeyError:
                return
        else:
            value = str(int(row.data_value*scale))
        try:
            group, data_symbol, scale = qttsensors[row.data_symbol]
        except KeyError:
            return
        if group not in self.instance[row.vmdb_id].keys():
            self.add_group(row.vmdb_id, group)
        SubElement(self.instance[row.vmdb_id][group],
                   "val",
                   ID=data_symbol,
                   index=str(row.data_number),
                   timestamp=row.data_time.strftime('%Y-%m-%dT%H:%M:%SZ')
                   ).text = value

    def add_station(self, vmdb_id, station_name):
        qtt_id = get_qtt_id(vmdb_id)
        if not qtt_id:
            qtt_id = vmdb_id
        self.instance[vmdb_id] = {'root': SubElement(self.root, "data", qttid=str(qtt_id))}

    def add_group(self, vmdb_id, group):
        self.instance[vmdb_id][group] = SubElement(self.instance[vmdb_id]['root'], group)

    def xml(self):
        return """<?xml version="1.0" encoding="UTF-8" standalone="yes"?>%s""" % tostring(self.root)
