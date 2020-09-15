#!/usr/bin/env python

from __future__ import with_statement

import sys
import zlib
import logging
import psycopg2

from numpy import float32
from Scientific.IO import NetCDF
from StringIO import StringIO
from xml.etree import ElementTree as ET
from datetime import datetime
from os import listdir, path
from optparse import OptionParser, OptionGroup
from requests_futures.sessions import FuturesSession

logging.basicConfig(level=logging.WARNING)
logger = logging.getLogger('madistoobsv2')
logger.setLevel(logging.INFO)

namespaces = {'SOAP-ENV': 'http://schemas.xmlsoap.org/soap/envelope/',
              'SOAP-ENC': 'http://schemas.xmlsoap.org/soap/encoding/',
              'xsi': 'http://www.w3.org/2001/XMLSchema-instance',
              'xsd': 'http://www.w3.org/2001/XMLSchema',
              'vai4': 'http://www.vaisala.com/schema/ice/iceMsgCommon/v1',
              'vai1': 'http://www.vaisala.com/wsdl/ice/uploadIceObservation/v2',
              'vai3': 'http://www.vaisala.com/schema/ice/obsMsg/v2',
              'jxc3': 'http://xml.vaisala.com/schema/jx/common/v3',
              'jxo3': 'http://xml.vaisala.com/schema/jx/observation/v3',
              }

try:
    for prefix, uri in namespaces.iteritems():
        ET.register_namespace(prefix, uri)
    namespaces_registered = True
except AttributeError:
    namespaces_registered = False
    # python2.7, nevermind

class ObsV2XML:
    def __init__(self):
        self.observation = ET.Element("{%s}observation" % namespaces['vai3'],
                                      attrib={'version': '2.0',
                                              'fastTrackQC': 'false'})
        self.instances = {}
        self.resultOfs = {}

    def instance(self, target):
        # target = (idType, id)
        if target not in self.instances:
            self.instances[target] = ET.SubElement(self.observation,
                                                   "{%s}instance" % namespaces['vai3'])
            targettag = ET.SubElement(self.instances[target],
                                      "{%s}target" % namespaces['vai3'])
            idtypetag = ET.SubElement(targettag, "{%s}idType" % namespaces['vai4'])
            idtypetag.text = target[0]
            idtag = ET.SubElement(targettag, "{%s}id" % namespaces['vai4'])
            idtag.text = target[1]
        return self.instances[target]


    def timestamp(self, target, timestamp):
        instance = self.instance(target)
        if (target, timestamp) not in self.resultOfs:
            self.resultOfs[(target, timestamp)] = ET.SubElement(instance,
                                                                "{%s}resultOf" % namespaces['vai3'],
                                                                attrib={'codespace': 'NTCIP',
                                                                    'timestamp': timestamp.strftime("%Y-%m-%dT%H:%M:%S"),
                                                                        'reason': 'scheduled',
                                                                        'version': '0.0.1'})
        return self.resultOfs[(target, timestamp)]

    def value(self, target, timestamp, code, value):
        resultOf = self.timestamp(target, timestamp)
        tag = ET.SubElement(resultOf,
                            "{%s}value" % namespaces['vai3'],
                            attrib={'code': code})
        tag.text = "%.2f" % value

    def xml(self):
        return ET.tostring(self.observation, encoding="UTF-8")

    def soapxml(self):
        return """<SOAP-ENV:Envelope xmlns:SOAP-ENV="http://schemas.xmlsoap.org/soap/envelope/" xmlns:SOAP-ENC="http://schemas.xmlsoap.org/soap/encoding/" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns:xsd="http://www.w3.org/2001/XMLSchema" xmlns:vai4="http://www.vaisala.com/schema/ice/iceMsgCommon/v1" xmlns:vai1="http://www.vaisala.com/wsdl/ice/uploadIceObservation/v2" xmlns:vai3="http://www.vaisala.com/schema/ice/obsMsg/v2">
<SOAP-ENV:Body>""" + self.xml() + """</SOAP-ENV:Body></SOAP-ENV:Envelope>"""

codes = {'temperature': ('essAirTemperature.0', 'celcius'),
         'relHumidity': ('essRelativeHumidity.0', 'percent'),
         'dewpoint': ('essDewpointTemp.0', 'celcius'),
         'windSpeed': ('essMaxWindGustSpeed.0', 'meter/sec'),
         'windDir': ('essAvgWindDirection.0', 'degree'),
         'roadSnowDepth': ('essRoadwaySnowDepth.0', 'centimeter'),
         'roadSnowpackDepth': ('essRoadwaySnowPackDepth.0', 'centimeter'),
         'visibility': ('essVisibility.0', 'meter'),
         #'visibilitySituation': ('essVisibilitySituation.0', 'meter'),
         'stationPressure': ('essAtmosphericPressure.0', 'pascal'),
         'solarRadiation': ('essSolarRadiation.0', 'watt/meter2'),
         'windGust': ('essMaxWindGustSpeed.0', 'meter/sec'),
         'windDirMax': ('essMaxWindGustDir.0', 'degree'),
         'precipStartTime': ('essPrecipitationStartTime.0', 'seconds since 1970-1-1 00:00:00.0'),
         'precipEndTime': ('essPrecipitationEndTime.0', 'seconds since 1970-1-1 00:00:00.0'),
         'precip3hr': ('essPrecipitationThreeHours.0', 'millimeter'),
         'precip6hr': ('essPrecipitationSixHours.0', 'millimeter'),
         'precip12hr': ('essPrecipitationTwelveHours.0', 'millimeter'),
         'maxTemp24Hour': ('essMaxTemp.0', 'celcius'),
         'minTemp24Hour': ('essMinTemp.0', 'celcius'),

         'waterLevel': ('essWaterDepth.0', 'meter'),

         'roadTemperature1': ('essSurfaceTemperature.1', 'celcius'),
         'roadSubsurfaceTemp1': ('essSubSurfaceTemperature.1', 'celcius'),
         'roadLiquidFreezeTemp1': ('essSurfaceFreezePoint.1', 'celcius'),
         'roadLiquidDepth1': ('essSurfaceWaterDepth.1', 'meter'),

         'roadTemperature2': ('essSurfaceTemperature.2', 'celcius'),
         'roadSubsurfaceTemp2': ('essSubSurfaceTemperature.2', 'celcius'),
         'roadLiquidFreezeTemp2': ('essSurfaceFreezePoint.2', 'celcius'),
         'roadLiquidDepth2': ('essSurfaceWaterDepth.2', 'meter'),

         'roadTemperature3': ('essSurfaceTemperature.3', 'celcius'),
         'roadSubsurfaceTemp3': ('essSubSurfaceTemperature.3', 'celcius'),
         'roadLiquidFreezeTemp3': ('essSurfaceFreezePoint.3', 'celcius'),
         'roadLiquidDepth3': ('essSurfaceWaterDepth.3', 'meter'),

         'roadTemperature4': ('essSurfaceTemperature.4', 'celcius'),
         'roadSubsurfaceTemp4': ('essSubSurfaceTemperature.4', 'celcius'),
         'roadLiquidFreezeTemp4': ('essSurfaceFreezePoint.4', 'celcius'),
         'roadLiquidDepth4': ('essSurfaceWaterDepth.4', 'meter'),

         'iceThickness': ('spectroSurfaceIceLayer.0', 'millimeter'),
         }

surfcodes = {'roadState1': 'essSurfaceStatus.1', 
             'roadState2': 'essSurfaceStatus.2',
             'roadState3': 'essSurfaceStatus.3',
             'roadState4': 'essSurfaceStatus.4',
             }

errorvalue = float32(3.4028235e+38)
surferrorvalue = -32767

def convert(value, oldunit, newunit):
    if oldunit == newunit:
        return value
    elif newunit == 'celcius':
        if oldunit == 'kelvin':
            return value - 273.15
    elif newunit == 'centimeter':
        if oldunit == 'millimeter':
            return value * 0.1
    logger.warning("No conversion available between %s and %s" % (oldunit, newunit))
    return None

surfvalues = {0: 0,        # No report
              1: 1,        # Dry
              2: 2,        # Moist
              3: 8,        # Moist and chemically treated
              4: 3,        # Wet
              5: 4,        # Wet and checmically treated
              6: 7,        # Ice
              7: 5,        # Frost
              8: 6,        # Snow
              9: 100,      # Snow/Ice watch
              10: 100,     # Warning
              11: 3,       # Wet above freezing
              12: 3,       # Wet below freezing
              13: None,      # Absorption
              14: None,      # Absorption at dewpoint
              15: 2,       # Dew
              16: 100,     # Black ice warning
              17: None,      # Other
              18: 9,       # Slush
              }

def process_netcdf_meta_file(filepath, outputdir=None, simpleServer=None, prepend=False, connectstring=None, dataProviders=None, reported=None, write_reported=None):
    f = NetCDF.NetCDFFile(filepath, 'r')
    process_netcdf_meta(f, outputdir, simpleServer, prepend, connectstring, dataProviders, reported, write_reported)

def process_netcdf_meta(f, outputdir=None, simpleServer=None, prepend=False, connectstring=None, dataProviders=None, reported=None, write_reported=None):
    conn = psycopg2.connect(connectstring)
    cur = conn.cursor()
    stations = []
    index = 0
    while True:
        index += 1
        try:
            f.variables['stationId'][index]
        except IOError:
            break
        stationid = ''.join(f.variables['stationId'][index])
        if prepend:
            stationid = 'MADIS_' + stationid
        if stationid in stations:
            continue
        lat = float(f.variables['latitude'][index])
        lon = float(f.variables['longitude'][index])
        name = ''.join(f.variables['stationName'][index]).decode("macroman")
        cur.execute("""UPDATE oe.station_identity
                       SET lon=%s,
                           lat=%s,
                           geom = ST_SetSRID(ST_MakePoint(%s, %s), 4326),
                           station_name=%s
                       WHERE xml_target_name=%s;""",
                    (lon, lat, lon, lat, name, stationid))
    cur.close()
    conn.commit()

def bg_cb(sess, resp):
    print resp.text

def process_netcdf_obs_file(filepath, outputdir=None, simpleServer=None, prepend=False, connectstring=None, dataProviders=None, reported=None, write_reported=None):
    """

    :rtype : object
    """
    f = NetCDF.NetCDFFile(filepath, 'r')
    process_netcdf_obs(f, outputdir, simpleServer, prepend, connectstring, dataProviders, reported, write_reported)

def process_netcdf_obs(f, outputdir=None, simpleServer=None, prepend=False, connectstring=None, dataProviders=None, reported=None, write_reported=None):
    if dataProviders:
        whitelist = dataProviders[0]
        logger.info('Only selecting dataproviders in %s' % whitelist)
        blacklist = dataProviders[1]
        logger.info('Ignoring dataproviders in %s' % blacklist)
    else:
        whitelist = None
        blacklist = None
    
    session = FuturesSession(max_workers=10)
    session.headers.update({"SOAPAction": '"putIceObservationV2_action"'})

    if reported is not None:
        latest_reported = reported
    else:
        #latest_reported = datetime(2000, 1, 1)
        latest_reported = 0

    index = -1
    while True:
        index += 1
        try:
            f.variables['stationId'][index]
        except IOError:
            break
        obsv2 = ObsV2XML()
        #reportTime = datetime.fromtimestamp(f.variables['reportTime'])
        reportTime = f.variables['reportTime'][index]
        if reportTime < reported:
            continue
        if reportTime > latest_reported:
            latest_reported = reportTime
        if whitelist or blacklist:
            dataProvider = ''.join(f.variables['dataProvider'][index])
            if whitelist and dataProvider not in whitelist:
                logger.debug('Skipping as %s not in %s' % (dataProvider, whitelist))
                continue
            if blacklist and dataProvider in blacklist:
                logger.debug('Skipping as %s in %s' % (dataProvider, blacklist))
                continue
        name = ''.join(f.variables['stationId'][index])
        if prepend:
            name = 'MADIS_' + name
        timestamp = datetime.fromtimestamp(f.variables['observationTime'][index])
        target = ('stationFullName', name)
        for madiscode, (obsv2code, unit) in codes.iteritems():
            oldunit = f.variables[madiscode].units
            value = f.variables[madiscode][index]
            if float32(value) == errorvalue:
                continue
            value = convert(value, oldunit, unit)
            if value:
                obsv2.value(target, timestamp, obsv2code, value)
        for madiscode, surfobsv2code in surfcodes.iteritems():
            value = f.variables[madiscode][index]
            if value == surferrorvalue:
                continue
            elif value not in surfvalues:
                logger.debug("Key %s not found in surface table." % value)
                continue
            value = surfvalues[value]
            if value:
                obsv2.value(target, timestamp, surfobsv2code, value)
        if obsv2.resultOfs:
            if simpleServer:
                session.post(simpleServer, data=obsv2.soapxml()) #, background_callback=bg_cb)
            elif outputdir:
                outpath = path.join(outputdir, "%s-%s.xml" % (name, timestamp.strftime("%Y%m%dT%H%M%SZ")))
                with open(outpath, 'w') as o:
                    o.write(obsv2.xml())
            else:
                print obsv2.xml()
    f.close()
    if write_reported:
        with open(write_reported, 'w') as f:
            f.write(str(latest_reported))

def process_directory(runfunc, directory, prepend=False, outputdir=None, simpleServer=None, connectstring=None, dataProviders=None, reported=None, write_reported=None):
    logger.debug("processing %s as a directory" % directory)
    for filename in listdir(directory):
        filepath = path.join(directory, filename)
        runfunc(filepath, outputdir, prepend, connectstring, dataProviders, reported, write_reported)

def process_target(runfunc, target, prepend=False, outputdir=None, simpleServer=None, connectstring=None, dataProviders=None, reported=None, write_reported=None):
    logger.debug("Deciding what %s is" % target)
    if path.isfile(target):
        runfunc(target, outputdir, simpleServer, prepend, connectstring, dataProviders, reported, write_reported)
    elif path.isdir(target):
        process_directory(runfunc, target, prepend, outputdir, simpleServer, connectstring, dataProviders, reported, write_reported)

def process_stdin(runfunc, gzip=False, prepend=False, outputdir=None, simpleServer=None, connectstring=None, dataProviders=None, reported=None, write_reported=None):
    #whole_file = sys.stdin.read()
    if gzip:
        f = NetCDF.NetCDFFile(StringIO(zlib.decompress(sys.stdin.read(), 16+zlib.MAX_WBITS)), 'r')
    else:
        f = NetCDF.NetCDFFile(StringIO(sys.stdin.read()), 'r')
    runfunc(f, outputdir, simpleServer, prepend, connectstring, dataProviders, reported, write_reported)

def main(argv=None):
    if argv is None:
        argv = sys.argv[1:]

    usage = "usage: %prog [options] "
    parser = OptionParser(usage=usage)
    parser.add_option("-i", dest="incoming", action="append",
                      help="Input file/directory.")
    parser.add_option("-o", dest="output",
                      help="Processed directory.")
    parser.add_option("-d", dest="debug", action="store_true",
                      help="Print debug messages.")
    parser.add_option("-p", dest="prepend", action="store_true",
                      help="prepend MADIS_ to site names.")
    parser.add_option("-m", dest="connectstring",
                      help="Update metadata information using db connect string.")
    parser.add_option("-s", dest="simpleServer",
                      help="SimpleServer address to send data to.")
    
    filter_group = OptionGroup(parser, "Filtering Options")
    filter_group.add_option("-w", dest="whitelist", action="append",
                            help="Whitelisted dataProvider's.")
    filter_group.add_option("-b", dest="blacklist", action="append",
                            help="Blacklisted dataProvider's.")
    filter_group.add_option("-r", dest="reported",
                            help="Process only data reported since this timestamp.")
    filter_group.add_option("--wr", dest="write_reported",
                            help="Write last reported to this file.")
    parser.add_option_group(filter_group)
    
    stdio_group = OptionGroup(parser, "STDIO Options")
    stdio_group.add_option("--stdin", dest="stdin", action="store_true",
                           help="Read netcdf from  standard input.")
    stdio_group.add_option("--gzip", dest="gzip", action="store_true",
                           help="STDIN is gzip'ed.")
    parser.add_option_group(stdio_group)
    
    (options, args) = parser.parse_args(argv)
    if options.incoming:
        incoming = options.incoming + args
    else:
        incoming = args

    if options.debug:
        logger.setLevel(logging.DEBUG)

    if options.connectstring:
        runfunc_file = process_netcdf_meta_file
        runfunc_stdin = process_netcdf_meta
    else:
        runfunc_file = process_netcdf_obs_file
        runfunc_stdin = process_netcdf_obs
    
    if options.reported:
        #reported = datetime.strptime(options.report, "%y%m%dT%H%M%S")
        reported = float(options.reported)
    else:
        reported = None

    if incoming:
        logger.debug("We're going to be working on %s" % incoming)
        for target in incoming:
            process_target(runfunc_file, target,
                           prepend=options.prepend,
                           outputdir=options.output,
                           simpleServer=options.simpleServer,
                           connectstring=options.connectstring,
                           dataProviders=(options.whitelist, options.blacklist),
                           reported=reported,
                           write_reported=options.write_reported)
    elif options.stdin:
        process_stdin(runfunc_stdin,
                      gzip=options.gzip,
                      outputdir=options.output,
                      simpleServer=options.simpleServer,
                      connectstring=options.connectstring,
                      dataProviders=(options.whitelist, options.blacklist),
                      reported=reported,
                      write_reported=options.write_reported)
    else:
        logger.critical("Nothing to process...?")
        return 1

if __name__ == "__main__":
    sys.exit(main())
