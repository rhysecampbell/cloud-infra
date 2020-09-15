#!/usr/bin/env python
#FORMAT PYTHON

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

from qttntcipobs import get_qtt_id

class VaisalaObsXML:
    def __init__(self, rows):
        self.root = Element("observation")
        self.root.attrib["version"] = "1.1.1"
        self.instance = {}
        self.resultOf = {}
        for row in rows:
            self.process_row(row)

    def process_row(self, row):
        if not row.vmdb_id in self.instance.keys():
            self.add_station(row.vmdb_id, row.station_name)
        if not row.data_time in self.resultOf[row.vmdb_id].keys():
            self.add_timestamp(row.vmdb_id, row.data_time)
        if row.data_symbol in ('WDM', 'WD', 'RH', 'VI', ):
            value = str(int(row.data_value))
        else:
            value = str(row.data_value)
        SubElement(self.resultOf[row.vmdb_id][row.data_time],
                   "value",
                   code=row.data_symbol,
                   no=str(row.data_number)
                   ).text = value

    def add_timestamp(self, vmdb_id, data_time):        
        self.resultOf[vmdb_id][data_time] = SubElement(self.instance[vmdb_id],
                                                       "resultOf",
                                                       timestamp=data_time.strftime('%Y-%m-%d %H:%M:%S'),
                                                       codeSpace="ICE_SD") 

    def add_station(self, vmdb_id, station_name):
        self.instance[vmdb_id] = SubElement(self.root, "instance")
        target = SubElement(self.instance[vmdb_id], "target")
        SubElement(target, "idType").text = "stationId"
        SubElement(target, "id").text = str(vmdb_id)
        SubElement(target, "name").text = station_name
        qtt_id = get_qtt_id(vmdb_id)
        if qtt_id:
            SubElement(target, "qttid").text = str(qtt_id)
        self.resultOf[vmdb_id] = {}

    def xml(self):
        return """<?xml version="1.0" encoding="UTF-8" standalone="yes"?>%s""" % tostring(self.root)
