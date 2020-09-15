#!/usr/bin/env python
#FORMAT PYTHON
import logging
import os
import web

from datetime import datetime
from time import mktime
from common import InjectingFilter, dbconfig, dbprinting

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


db = web.database(**dbconfig)
db.printing = dbprinting

CURDIR = os.path.dirname(__file__)

logfilter = InjectingFilter()
log = logging.getLogger('app.common.datex2')
log.addFilter(logfilter)

DATEX_ENUM = {}
ENUMPATH = os.path.join(CURDIR, 'datex2')
for s in ['AL', 'CL', 'FDS', 'HCS', 'MST', 'PW', 'RS', 'ST', 'RD']:
    enumfile = os.path.join(ENUMPATH, s + '.enum')
    DATEX_ENUM[s] = open(enumfile).read().splitlines()

## Note that the values here are from postgres to datex2 units.
## It may not make sense if you apply these conversions to values from other
## sources like Oracle!
## We cannot update the scaling values in postgres because vaisalaobs also
## use them...
## tl;dr: datex2 != postgres != Oracle
SCALARS = {'IL': 0.001,   # mm -> m
           'WL': 0.001,   # mm -> m
           'SL': 0.001,   # mm -> m
           'FR': 0.01,    # %  -> .
           'WS': 3.6,     # m/s -> km/h
           'WSM': 3.6,    # m/s -> km/h
           'PR': 0.001,   # mm -> m
           'WT': 0.001,   # mm -> m
           'SH': 0.0001,  # 100um -> m
           'GE': 0.001,   # g/m2 -> kg/m2
           }


def get_datex_id(data_symbol, data_number):
    """Return datex2 sensor specific index number"""
    return db.select('exportws.sensorindex',
                     where="data_symbol=$data_symbol \
                            and data_number=$data_number",
                     vars={'data_symbol': data_symbol,
                           'data_number': data_number, },
                     )[0].datex_id


def get_datex2grouptype(sensor):
    """Return datex2 xsitype for specific sensor id"""
    symbol = db.select('exportws.sensorindex',
                       what="data_symbol",
                       where="datex_id=$datex_id",
                       vars={'datex_id': int(sensor), },
                       )[0].data_symbol
    grouptype = db.select('exportws.xmltags', what="xsitype",
                          where="data_symbol=$data_symbol",
                          vars={'data_symbol': symbol, },
                          )[0].xsitype
    return grouptype


def get_mst_date(vmdb_id=None):
    """Return the date vmdb_id was last modified."""
    if vmdb_id:
        result = date = db.select('exportws.stations',
                                  what="version",
                                  where="vmdb_id=$vmdb_id",
                                  vars={'vmdb_id': vmdb_id, })
        if len(result) == 1:
            date = result[0].version
        else:
            date = update_mst_date(vmdb_id)
    else:
        date = db.query("""SELECT max(version) as max
                           FROM exportws.stations""")[0].max
    return date


def update_mst_date(vmdb_id):
    """Update DATEX2DB station datestimestamp & return it"""
    now = int(mktime(datetime.now().timetuple()))
    if not db.update('exportws.stations',
                     where="vmdb_id = $vmdb_id",
                     version=now, vars={'vmdb_id': vmdb_id, }):
        db.insert('exportws.stations', vmdb_id=vmdb_id, version=now, )
    return now


def get_datex_group(vmdb_id, datex_id,):
    """Return station specific group_id for sensor."""
    result = db.select('exportws.sensors',
                       what="group_id",
                       where="""vmdb_id = $vmdb_id
                                and datex_id = $datex_id""",
                       vars={'vmdb_id': vmdb_id,
                             'datex_id': datex_id}
                       )
    if len(result) == 1:
        return result[0].group_id
    else:
        return None


def get_datex2index_groups(vmdb_id, ):
    """
    Return list of datex2 sensors associated with vmdb_id.

    Intended for use generating MST's.
    """
    d2i = {}
    groups = db.select('exportws.groups', where="vmdb_id = $vmdb_id",
                       vars={'vmdb_id': vmdb_id, })
    sql = """select *
             from exportws.sensors as s,
                  exportws.groups as g,
                  exportws.lanes as l,
                  exportws.sensorindex as si,
                  exportws.xmltags as x
             where g.vmdb_id = s.vmdb_id
               and l.vmdb_id = s.vmdb_id
               and g.group_id = s.group_id
               and l.data_number = g.data_number
               and si.datex_id = s.datex_id
               and x.data_symbol = si.data_symbol
               and s.vmdb_id = $vmdb_id
               and s.group_id = $group_id
             order by si.datex_id asc"""
    for g in groups:
        d2i[g.group_id] = db.query(sql, vars={'vmdb_id': vmdb_id,
                                   'group_id': g.group_id}
                                   ).list()
    return d2i


def get_datex2index(vmdb_id):
    """
    Return group of dictionary of datex2 sensors associated with vmdb_id.

    keys are datex_id's, values are rows.

    Intended for use generating paylods.
    """
    # Joined these tables to allow us to use x.xsitype when marking faulty
    # sensors. Perhaps it would be better to revert to the old simple select
    # and get xsitype later as required?
    rows = db.query("""SELECT * FROM exportws.sensors se, exportws.xmltags x,
                                     exportws.sensorindex si
                       WHERE vmdb_id=$vmdb_id
                         AND se.datex_id = si.datex_id
                         AND si.data_symbol = x.data_symbol""",
                     vars={"vmdb_id": vmdb_id}
                     )
    datex2index = {}
    for row in rows:
        datex2index[row.datex_id] = row
    return datex2index


def update_datex2index(vmdb_id, datex_id, data_number):
    """Update the datex2 index."""
    group_id = get_datex_group(vmdb_id, datex_id)
    if group_id:
        log.debug("datex_id=%i vmdb_id=%id group_id=%i new=False" \
                  % (datex_id, vmdb_id, group_id))
        return group_id
    # If we're looking at CL, we need to set the data_number to 1... yay.
    if datex_id in (213, 214, 215, 216):
        data_number = 1
    grouptype = get_datex2grouptype(datex_id)
    if not db.select('exportws.stations', where="vmdb_id=$vmdb_id",
                            vars={"vmdb_id": vmdb_id}):
        db.insert('exportws.stations', vmdb_id=vmdb_id, )
    if not db.select('exportws.lanes',
                            where="vmdb_id=$vmdb_id AND data_number=$data_number",
                            vars={"vmdb_id": vmdb_id,
                                  "data_number": data_number}):
        db.insert('exportws.lanes',
                         vmdb_id=vmdb_id,
                         data_number=data_number)
    groups = db.select('exportws.groups',
                              where="vmdb_id = $vmdb_id",
                              order="group_id ASC",
                              vars={'vmdb_id': vmdb_id,
                                    'data_number': data_number}
                              )
    group_id = 0
    for group in groups:
        group_id = group.group_id
        if group.data_number == data_number and group.xsitype == grouptype:
            break
    else:
        group_id += 1
        db.insert('exportws.groups',
                         vmdb_id=vmdb_id, data_number=data_number,
                         group_id=group_id, xsitype=grouptype)
    db.insert('exportws.sensors', vmdb_id=vmdb_id,
                     datex_id=datex_id, group_id=group_id, enabled=True)
    update_mst_date(vmdb_id)
    log.debug("datex_id=%i vmdb_id=%id group_id=%i new=True" \
              % (datex_id, vmdb_id, group_id))
    return group_id


def format_value(value, data_symbol):
    if value is None:
        return value
    elif data_symbol in ('WDM', 'WD', 'RH', 'VI', 'RL', ):
        value = int(value)
    elif data_symbol in DATEX_ENUM:
        value = int(value)
        try:
            value = DATEX_ENUM[data_symbol][int(value)]
        except IndexError:
            log.debug("FIXME: No %s enum for %s" \
                      % (data_symbol, value))
            return None
    else:
        if data_symbol in SCALARS:
            value = value * SCALARS[data_symbol]
        ## FIXME: Ensures precision is retained but adds too many 0's
        value = "%.5f" % (value)
    return str(value)


def datex_id_to_vmdb_id(datex_station_id):
    if 'GB_HA_' in datex_station_id:
        return datex_station_id[6:]
    if 'HA_2012_DC_1_' in datex_station_id:
        return datex_station_id[13:]


def get_measurementside(vmdb_id):
    try:
        side = db.select('exportws.stations',
                         what="measurementside",
                         where="vmdb_id=$vmdb_id",
                         vars={'vmdb_id': vmdb_id, }
                         )[0].measurementside
        if side == None:
            side = "unknown"
    except IndexError:
        side = "unknown"
    return side


def lone_dsc(vmdb_id):
    """Returns True if only 1 surface sensor in lane3, False otherwise."""
    try:
        result = db.select('exportws.groups',
                           where="vmdb_id=$vmdb_id AND xsitype='SurfaceInformation'",
                           vars={'vmdb_id': vmdb_id, })
        if (len(result)==1 and result[0].data_number==3):
            return True
    except IndexError:
        pass
    return False


class DataXML:
    def __init__(self, rows, region_id=None):
        self.region_id = region_id
        self.root = Element("d2LogicalModel")
        self.root.attrib["xmlns:xsd"] = "http://www.w3.org/2001/XMLSchema"
        self.root.attrib["modelBaseVersion"] = "2.0RC2"
        self.root.attrib["xmlns"] = "http://datex2.eu/schema/2_0RC2/2_0"
        self.root.attrib["xmlns:xsi"] = "http://www.w3.org/2001/XMLSchema-instance"
        self.root.attrib["xsi:schemaLocation"] = "http://datex2.eu/schema/2_0RC2/2_0 https://birice.vaisala.com:10080/static/DATEXIISchema_2_0RC2_2_0_EssExtension_2_1.xsd"

        exchange = SubElement(self.root, "exchange")
        supplierIdentification = SubElement(exchange, "supplierIdentification")
        SubElement(supplierIdentification, "country").text = "gb"
        SubElement(supplierIdentification, "nationalIdentifier").text = "VaisalaLtd"
        self.payload = SubElement(self.root, "payloadPublication")
        self.payload.attrib["xsi:type"] = "MeasuredDataPublication"
        self.payload.attrib["lang"] =  "en"
        self.publicationTime = SubElement(self.payload, "publicationTime")
        publicationCreator = SubElement(self.payload, "publicationCreator")
        SubElement(publicationCreator, "country").text = "gb"
        SubElement(publicationCreator, "nationalIdentifier").text = "VaisalaLtd"
        self.measurementsitetablereference = SubElement(self.payload, "measurementSiteTableReference",
                                                        targetClass="MeasurementSiteTable")
        headerInformation = SubElement(self.payload, "headerInformation")
        SubElement(headerInformation, "confidentiality").text = "internalUse"
        SubElement(headerInformation, "informationStatus").text = "technicalExercise"

        self.resultOf = {}
        self.datex2index = {}
        # As we add data, we'll keep a record of what indexes have gone
        # so that we can fill in faults for missing sensors easily later.
        self.index = {}  # (vmdb_id, data_time): []

        for row in rows:
            self.process_row(row)

    def update_datex2index(self, vmdb_id, data_time, datex_id, data_number):
        if not vmdb_id in self.datex2index:
            self.datex2index[vmdb_id] = get_datex2index(vmdb_id)
        if datex_id not in self.datex2index[vmdb_id]:
            update_datex2index(vmdb_id, datex_id, data_number)
            self.datex2index[vmdb_id] = get_datex2index(vmdb_id)
        if not (vmdb_id, data_time) in self.index:
            self.index[(vmdb_id, data_time)] = []
        self.index[(vmdb_id, data_time)].append(datex_id)

    def process_row(self, row):
        formatted_value = format_value(row.data_value, row.data_symbol)
        if formatted_value is None:
            return None
        self.update_datex2index(row.vmdb_id, row.data_time, row.datex_id, row.data_number)
        if (row.vmdb_id, row.data_time) not in self.resultOf:
            measurements = SubElement(self.payload, "siteMeasurements")
            SubElement(measurements, "measurementSiteReference", targetClass="MeasurementSiteRecord", id="GB_HA_%i" % row.vmdb_id)
            SubElement(measurements, "measurementTimeDefault").text = row.data_time.strftime('%Y-%m-%dT%H:%M:%S+00:00')
            self.resultOf[(row.vmdb_id, row.data_time)] = SubElement(measurements, "siteMeasurementsExtension")
        metdata = SubElement(self.resultOf[(row.vmdb_id, row.data_time)], "metData", index=str(row.datex_id))
        metdata.attrib['xsi:type'] = row.xsitype
        innertag = SubElement(metdata, row.xmltagname)
        innertag.text = formatted_value

    def guess_region(self):
        if self.region_id:
            return self.region_id
        else:
            #FIXME: agreed region_id would be station_id for single station requests.
            return self.resultOf.keys()[0][0]

    def set_region(self):
        region_id = self.guess_region()
        region_string = "HA_2012_DC_1_%s" % region_id
        self.measurementsitetablereference.attrib['id'] = region_string

    def update_version(self):
        if self.region_id:
            region_id = self.region_id
            self.measurementsitetablereference.attrib["version"] = str(get_mst_date())
        else:
            region_id = self.guess_region()
            self.measurementsitetablereference.attrib["version"] = str(get_mst_date(region_id))
        for measurement in self.payload.findall("siteMeasurements"):
            reference = measurement.find("measurementSiteReference")
            vmdb_id = datex_id_to_vmdb_id(reference.attrib['id'])
            reference.attrib['version'] = str(get_mst_date(vmdb_id))

    def check_for_missing(self):
        """Set all missing sensors to fault."""
        for (vmdb_id, data_time), indexlist in self.index.items():
            for index in self.datex2index[vmdb_id]:
                if index not in indexlist:
                    metdata = SubElement(self.resultOf[(vmdb_id, data_time)], "metData", index=str(index))
                    metdata.attrib['xsi:type'] = self.datex2index[vmdb_id][index].xsitype
                    innertag = SubElement(metdata, "fault")
                    innertag.text = "true"

    def xml(self):
        self.update_version()
        self.check_for_missing()
        self.set_region()
        self.publicationTime.text = datetime.utcnow().strftime('%Y-%m-%dT%H:%M:%S+00:00')
        return """<?xml version="1.0" encoding="utf-8"?><soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/" xmlns:env="http://www.w3.org/2001/XMLSchema-instance" xmlns:xdt="http://www.w3.org/2004/07/xpath-datatypes" xmlns:xsd="http://www.w3.org/2001/XMLSchema" env:schemaLocation="http://schemas.xmlsoap.org/soap/envelope/ http://schemas.xmlsoap.org/soap/envelope/"><soapenv:Body>%s</soapenv:Body></soapenv:Envelope>""" % tostring(self.root)


class MstXML:
    def __init__(self, station_row=None, region_row=None):
        if not (region_row or station_row):
            raise ValueError('Requires region_row or station_row')

        self.root = Element("d2LogicalModel")
        self.root.attrib["xmlns:xsd"] = "http://www.w3.org/2001/XMLSchema"
        self.root.attrib["modelBaseVersion"] = "2.0RC2"
        self.root.attrib["xmlns"] = "http://datex2.eu/schema/2_0RC2/2_0"
        self.root.attrib["xmlns:xsi"] = "http://www.w3.org/2001/XMLSchema-instance"
        self.root.attrib["xsi:schemaLocation"] = "http://datex2.eu/schema/2_0RC2/2_0 https://birice.vaisala.com:10080/static/DATEXIISchema_2_0RC2_2_0_EssExtension_2_1.xsd"
        self.exchange = SubElement(self.root, "exchange")
        supplierIdentification = SubElement(self.exchange, "supplierIdentification")
        SubElement(supplierIdentification, "country").text = "gb"
        SubElement(supplierIdentification, "nationalIdentifier").text = "VaisalaLtd"
        self.payload = SubElement(self.root, "payloadPublication")
        self.payload.attrib["xsi:type"] = "MeasurementSiteTablePublication"
        self.payload.attrib["lang"] = "en"
        self.publicationTime = SubElement(self.payload, "publicationTime")
        publicationCreator = SubElement(self.payload, "publicationCreator")
        SubElement(publicationCreator, "country").text = "gb"
        SubElement(publicationCreator, "nationalIdentifier").text = "VaisalaLtd"
        headerInformation = SubElement(self.payload, "headerInformation")
        SubElement(headerInformation, "confidentiality").text = "internalUse"
        SubElement(headerInformation, "informationStatus").text = "technicalExercise"

        if region_row:
            self.mst = SubElement(self.payload, "measurementSiteTable",
                                  id="HA_DC_2012_1_%i" % region_row.vmdb_id,
                                  version=str(get_mst_date()))
            #TODO: deal with region mst
            pass
        else:
            self.mst = SubElement(self.payload, "measurementSiteTable",
                                  id="HA_DC_2012_1_%i" % station_row.vmdb_id,
                                  version=str(get_mst_date(station_row.vmdb_id)))
            station_row = {station_row.vmdb_id: station_row}
        SubElement(self.mst, "measurementSiteTableIdentification").text = "VaisalaLtd"

        datex2index_groups = {}
        for station_id in station_row: 
            datex2index_groups[station_id] = get_datex2index_groups(station_id)

        for station_id, groups in datex2index_groups.items():
            row = station_row[station_id]
            msr = SubElement(self.mst, "measurementSiteRecord",
                             id="GB_HA_%i" % station_id,
                             version=str(get_mst_date(station_id)))
            SubElement(msr, "measurementEquipmentReference").text = str(station_id)
            SubElement(SubElement(SubElement(msr, "measurementSiteName"), "values"), "value").text = row.station_name

            msl = SubElement(msr, "measurementSiteLocation")
            msl.attrib["xsi:type"] = "Point"
            tpegpl = SubElement(msl, "tpegPointLocation")
            tpegpl.attrib["xsi:type"] = "TpegSimplePoint"
            SubElement(tpegpl, "tpegDirection").text = get_measurementside(row.vmdb_id)
            SubElement(tpegpl, "tpegSimplePointLocationType").text = "nonLinkedPoint"
            point = SubElement(tpegpl, "point")
            point.attrib["xsi:type"] = "TpegNonJunctionPoint"
            pointcoordinates = SubElement(point, "pointCoordinates")
            SubElement(pointcoordinates, "latitude").text = str(row.latitude)
            SubElement(pointcoordinates, "longitude").text = str(row.longitude)
            pointname = SubElement(point, "name")
            SubElement(SubElement(SubElement(pointname, "descriptor"), "values"), "value").text = row.station_name
            SubElement(pointname, "tpegOtherPointDescriptorType").text = "pointName" 

            msre = SubElement(msr, "measurementSiteRecordExtension")
            SubElement(msre, "measurementSiteNumberOfLanes").text = str(len(db.select('exportws.lanes',
                                                                                      where="vmdb_id=$vmdb_id",
                                                                                      vars={'vmdb_id': row.vmdb_id, }
                                                                                      ).list()))
            for group, sensors in groups.items():
                sensorgroup = SubElement(msre, "sensorGroup")

                # If we have only a DSC then force the data_number to 1.
                if lone_dsc(station_id):
                    data_number = 1
                else:
                    # The data_number of the first sensor should match all
                    # others, except CL which will always be set on its own.
                    data_number = sensors[0].data_number

                if sensors[0].xsitype == u'AtmosphericInformation':
                    grouptype = "atmospheric"
                elif sensors[0].xsitype == u'SurfaceInformation':
                    grouptype = "surface%i" % data_number
                elif sensors[0].xsitype == u'EquipmentStatusInformation':
                    grouptype = "equipment"
                SubElement(sensorgroup, "groupType").text = grouptype

                if sensors[0].lane_direction:
                    groupname = sensors[0].lane_direction
                else:
                    groupname = "unknown"
                SubElement(sensorgroup, "groupName").text = groupname

                if sensors[0].lane_name:
                    lane = sensors[0].lane_name
                else:
                    lane = "lane%i" % data_number
                SubElement(sensorgroup, "lane").text = lane 

                SubElement(sensorgroup, "specificMetDataValueType").text =  sensors[0].xsitype[0].lower() + sensors[0].xsitype[1:]

                for sensor in sensors:
                    s = SubElement(sensorgroup, "measurementSpecificCharacteristics", index=str(sensor.datex_id))

                    if sensor.xsitype == u'SurfaceInformation' and sensor.lane_name:
                        lane = sensor.lane_name
                    elif sensor.data_symbol == 'CL':
                        if sensor.lane_name:
                            lane = sensor.lane_name
                        else:
                            if lone_dsc(station_id):
                                lane = "lane1"
                            else:
                                lane = "lane%i" % sensor.data_number
                    SubElement(s, "specificLane").text = lane

                    if sensor.reverse:
                        SubElement(SubElement(s, "locationCharacteristicsOverride"), "reversedFlow").text = "true"

                    SubElement(s, "xmlTagName").text = sensor.xmltagname
                    SubElement(s, "dataType").text = sensor.datatype
                    SubElement(s, "measurementUnit").text = sensor.measurementunit

    def xml(self):
        self.publicationTime.text = datetime.utcnow().strftime('%Y-%m-%dT%H:%M:%S+00:00')
        return tostring(self.root)
