#!/usr/bin/env python

import re
import os
import web
import json
import ConfigParser

from urlparse import urlparse, urlsplit, urlunsplit
from datetime import datetime, timedelta
from base64 import b64decode
from urlparse import urljoin
from os.path import split as pathsplit

config = ConfigParser.RawConfigParser()
config.read('/etc/vaisala-config/settserver.cfg')
db = {}
for d in 'clouddb', 'authdb', 'metardb', 'lightningdb', 'madisdb', 'weatherzones':
    params = dict((p, config.get(d, p)) for p in ['dbn', 'database', 'host', 'port', 'user', 'password'])
    params['pooling'] = False
    db[d] = web.database(**params)

urls = (
	'/nagios-tests', 'Nagios',
        '/api/?v?(.*)/rwis/latest/(.*)', 'Obs',
        '/api/?v?(.*)/metar/latest/(.*)', 'Metar',
        '/api/?v?(.*)/metar/latest', 'Metar',
        '/api/?v?(.*)/madis/latest', 'Madis',
        '/api/?v?(.*)/madis/vao', 'MadisVao',
        '/api/?v?(.*)/rwis/graph', 'ObsGraph',
        '/api/?v?(.*)/radar/list/uk', 'ListRadarUK',
        '/api/?v?(.*)/radar/list/us', 'ListRadarUS',
        '/api/?v?(.*)/radar/list/(.*)', 'ListRadar',
        '/api/?v?(.*)/roles', 'Roles',
        '/api/?v?(.*)/lightning/point', 'LightningPoint',
        '/api/?v?(.*)/wwa/alerts', 'alertPoly'
        )

app = web.application(urls, globals())

def check_authn(username, password):
    result = db['authdb'].query("""select username from users
                                   where username = $username 
                                   and password = md5($password)""",
                                vars={'username': username,
                                      'password': password})
    return len(list(result)) == 1

def check_authz(username, role):
    result = db['authdb'].query("""select username from tomcat_roles
                                   where username = $username
                                     and role = $role""",
                                vars={'username': username, 'role': role})
    return len(list(result)) == 1

def authenticate():
    web.header('WWW-Authenticate','Basic realm="Auth example"')
    web.ctx.status = '401 Unauthorized'
    return

def check_auth(role=None):
    try:
        username, password = b64decode(web.ctx.env['HTTP_AUTHORIZATION'][6:]).split(':')
    except KeyError:
        return False
    if not check_authn(username, password):
        return False
    if role and not check_authz(username, role):
        return False
    return True

class Obs:
    def GET(self, version=1, role=None):
        if not role:
            raise web.notfound("Please specify a role")
        if not check_auth(role):
            return authenticate()
        SQL1 = """select station_identity.stn_id "id",
                 station_identity.station_name "name" ,
                 station_identity.last_updated "time" ,
                 station_identity.lat ,
                 station_identity.lon ,
                 station_identity.image1_url ,
                 station_identity.image2_url ,
                 station_identity.forecast_url , 
    --             sensor_identity.symbol "type",
                 sensor_alias.alias "type",
                 sensor_identity.symbol "symbol",
                 sensor_alias.sensor_no "sensor_no",
                 data_value.nvalue "value",
                 data_value.status
          from oe.station_identity
          left outer join oe.data_value on station_identity.stn_id = data_value.stn_id
          left outer join oe.sensor_identity on station_identity.stn_id = sensor_identity.stn_id
          left outer join oe.sensor_alias on sensor_alias.symbol = sensor_identity.symbol,
          oe.station_alias, oe.station_alias_identity
          where data_value.creationtime = station_identity.last_updated
          and station_identity.stn_id = station_alias.stn_id
          and station_alias.v_region_id = station_alias_identity.v_region_id
          and data_value.sensor_id = sensor_identity.sensor_id
          and station_alias_identity.v_region_name = $role
          and sensor_identity.blacklisted = false
          and sensor_identity.symbol in (select symbol from oe.sensor_alias
                                                       where in_use = true )"""
        SQL2 = """select station_identity.stn_id "id" ,
                  station_identity.station_name "name" ,
                  station_identity.last_updated "time" ,
                  station_identity.lat ,
                  station_identity.lon ,
                  station_identity.image1_url ,
                  station_identity.image2_url ,
                  station_identity.forecast_url 
                  from oe.station_identity, oe.station_alias, oe.station_alias_identity
                  where station_identity.stn_id = station_alias.stn_id
                    and station_alias.v_region_id = station_alias_identity.v_region_id
                    and station_alias_identity.v_region_name = $role"""

        standardkeys = ["id", "lon", "lat", "name"]

        stations = {}
        result = db['clouddb'].query(SQL1, vars={'role': role})
        domain = www_domain()
        for row in result:
            stationname = row['name']
            if stationname not in stations:
                stations[stationname] = dict((k, row[k]) for k in standardkeys)
                stations[stationname]['time'] = row['time'].strftime("%Y-%m-%d %H:%M:%S.0")
                stations[stationname]['observations'] = []
                stations[stationname]['forecast_url'] = set_url_scheme(row['forecast_url'])
                for image in ("image1_url", "image2_url"):
                    if not row[image]:
                        continue
                    elif row[image].startswith("http://"):
                        imageurl = row[image]
                    else:
                        imageurl = "%s/images/%s" % (domain, row[image])
                    stations[stationname][image] = set_url_scheme(imageurl)
            # Convert m14 status codes to ntcip equivalents
            if row.symbol in ("36", "51", "66", "81"):
                last_digit = int(row.value % 10)
                value = [2, 3, 4, 5, 6, 13, 10, 8, 4, 1][last_digit]
            else:
                value = row.value
            stations[stationname]['observations'].append({"value": value,
                                                        "type": row["type"],
                                                        "no": row["sensor_no"],
                                                        "status": row["status"]})
        result = db['clouddb'].query(SQL2, vars={'role': role}) 
        for row in result:
            stationname = row['name']
            if stationname not in stations:
                stations[stationname] = dict((k, row[k]) for k in standardkeys)
                if row['time']:
                    stations[stationname]['time'] = row['time'].strftime("%Y-%m-%d %H:%M:%S.0")
		    stations[stationname]['forecast_url'] = set_url_scheme(row['forecast_url'])
                for image in ("image1_url", "image2_url"): #FIXME: silly to double this up!
                    if not row[image]:
                        continue
                    elif row[image].startswith("http://"):
                        imageurl = row[image]
                    else:
                        imageurl = "%s/images/%s" % (domain, row[image])
                    stations[stationname][image] = set_url_scheme(imageurl)
        result = { "stations": list(stations.values()) }
        web.header('Content-Type', 'application/json')
        return json.dumps(result) #, indent=4, separators=(',', ': '))


class Metar:
    def GET(self, version=1, role=None):
        if role == "global": #DEPRECATED: For rds
            role = None
        if not check_auth(role):
            return authenticate()
        i = web.input(left=None, right=None, top=None, bottom=None)
        if role is None and None in (i.left, i.right, i.top, i.bottom):
            raise web.notfound("You must specify a role or bounding box.")
        sqlvars={'role': role,
	         'left': i.left,
	         'right': i.right,
	         'top': i.top,
	         'bottom': i.bottom}
        SQL = """select station_identity.stn_id "id",
                 station_identity.xml_target_name "icao" ,
                 station_identity.last_updated "time" ,
                 station_identity.lat "lat" ,
                 station_identity.lon "lon" ,
                 station_identity.alt "altitude" ,
                 station_identity.station_name "name" ,
                 station_identity.forecast_url "forecast_url" ,
                 sensor_identity.symbol "type",
                 data_value.nvalue "value" ,
                 data_value.nvalue_str "text" ,
                 enumerated_types.full_str "description"
          from oe.station_identity
          left outer join oe.data_value on station_identity.stn_id = data_value.stn_id
          left outer join oe.sensor_identity on station_identity.stn_id = sensor_identity.stn_id,
          oe.enumerated_types"""
        if role is not None:
            SQL += """, oe.station_alias, oe.station_alias_identity"""
        SQL += """ where data_value.creationtime = station_identity.last_updated"""
        if role is not None:
            SQL += """ and station_identity.stn_id = station_alias.stn_id
                       and station_alias.v_region_id = station_alias_identity.v_region_id"""
        SQL += """ and data_value.sensor_id = sensor_identity.sensor_id"""
        if role is not None:
            SQL += " and station_alias_identity.v_region_name = $role"
        if None not in (i.left, i.right, i.top, i.bottom):
            SQL += " and station_identity.geom && ST_MakeEnvelope($left, $bottom, $right, $top, 4326)"
        SQL += """ and sensor_identity.blacklisted = false
          and sensor_identity.symbol in ('M_rawMessage','S_rawMessage',
                                         'M_visibility','S_visibility',
                                         'M_windDirection','S_windDirection',
                                         'M_windSpeed', 'S_windSpeed',
                                         'M_windGustSpeed', 'S_windGustSpeed',
                                         'M_airTemperature', 'S_airTemperature',
                                         'M_dewPoint','S_dewPoint',
                                         'M_wxCode','S_wxCode',
                                         'M_skyCondition','S_skyCondition',
                                         'M_A_altim','S_A_altim')
          and (enumerated_types.enumerator = data_value.nvalue OR data_value.nvalue_str is null)
          and  sensor_identity.symbol  like '__' || enumerated_types.symbol;"""

        standardkeys = ["id", "lon", "lat", "time", "name", "altitude", "icao"]
        observationkeys = ["value", "text", "type", "description"]

        stations = {}
        rows = db['metardb'].query(SQL, sqlvars)
        for row in rows:
            stationid = row['id']
            if stationid not in stations:
                stations[stationid] = dict((k, row[k]) for k in standardkeys)
                stations[stationid]['time'] = row['time'].strftime("%Y-%m-%d %H:%M:%S.0")
                stations[stationid]['observations'] = []
                stations[stationid]['forecast_url'] = set_url_scheme(row['forecast_url'])
            stations[stationid]['observations'].append(dict((k, row[k]) for k in observationkeys))
        web.header('Content-Type', 'application/json')
        result = { "stations": list(stations.values()) }
        return json.dumps(result) #, indent=4, separators=(',', ': '))


class Madis:
    def GET(self, version=1):
        if not check_auth():
            return authenticate()
        i = web.input(left=None, right=None, top=None, bottom=None, state=None)
        sqlvars={'left': i.left,
	         'right': i.right,
	         'top': i.top,
	         'bottom': i.bottom,
                 'state': i.state}
        SQL = """select station_identity.stn_id "id",
                 station_identity.xml_target_name "target_name" ,
                 station_identity.last_updated "time" ,
                 station_identity.lat "lat" ,
                 station_identity.lon "lon" ,
                 station_identity.alt "altitude" ,
                 station_identity.station_name "name" ,
                 station_identity.forecast_url "forecast_url" ,
                 sensor_identity.symbol "type",
                 data_value.nvalue "value" ,
                 data_value.nvalue_str "text"
          from oe.station_identity
          left outer join oe.data_value on station_identity.stn_id = data_value.stn_id
          left outer join oe.sensor_identity on station_identity.stn_id = sensor_identity.stn_id """
        if i.state is not None:
            SQL += """INNER JOIN geo_states on ST_Intersects(station_identity.geom, geo_states.geom)
                      WHERE geo_states.state = $state
                        AND """
        else:
            SQL += """WHERE """
        SQL += """data_value.creationtime = station_identity.last_updated
                  and data_value.sensor_id = sensor_identity.sensor_id """
        if None not in (i.left, i.right, i.top, i.bottom):
            SQL += """and station_identity.geom && ST_MakeEnvelope($left, $bottom, $right, $top, 4326)"""
        elif i.state is None:
            raise web.notfound("specify some sort of parameter")
        SQL += """and sensor_identity.blacklisted = false"""

        standardkeys = ["id", "lon", "lat", "time", "name", "altitude", "target_name"]
        observationkeys = ["value", "text", "type"]

        stations = {}
        rows = db['madisdb'].query(SQL, sqlvars)
        for row in rows:
            stationid = row['id']
            if stationid not in stations:
                stations[stationid] = dict((k, row[k]) for k in standardkeys)
                stations[stationid]['time'] = row['time'].strftime("%Y-%m-%d %H:%M:%S.0")
                stations[stationid]['observations'] = []
                stations[stationname]['forecast_url'] = set_url_scheme(row['forecast_url'])
            stations[stationid]['observations'].append(dict((k, row[k]) for k in observationkeys))
        web.header('Content-Type', 'application/json')
        result = { "stations": list(stations.values()) }
        return json.dumps(result) #, indent=4, separators=(',', ': '))


class MadisVao:
    def GET(self, version=1):
        if not check_auth():
            return authenticate()
        stnid = web.input().stnid
        SQL = """SELECT st.station_name as Name, dv.stn_id as id, st.lat, st.lon, dv.sensor_id, dv.creationtime as time,se.symbol, dv.nvalue as value
                   FROM oe.data_value dv, oe.sensor_identity se, oe.station_identity st
                 WHERE dv.stn_id = $stnid
                   AND st.stn_id = dv.stn_id
                   AND se.stn_id = dv.stn_id
                   AND dv.sensor_id = se.sensor_id
                   AND dv.creationtime > now() - '3 hours'::interval
                 ORDER BY dv.creationtime ASC;"""
        rows = db['madisdb'].query(SQL, {'stnid': stnid, })
        if not rows:
            raise web.notfound()
        timestamps = {}
        for row in rows:
            if not row.time in timestamps:
                timestamps[row.time] = {}
            timestamps[row.time][row.symbol] = row.value
        vao = "@ XX001\n"
        lines = []
        sorted_timestamps = timestamps.keys()
        sorted_timestamps.sort()
        for timestamp in sorted_timestamps:
            try:
                lines.append("%s AT1=%s BT1= ??? DT1= ??? GT1=??? PS1= ??? SS1= ??? ST1=%s WS1= ???" \
                             % (timestamp.strftime("%H:%M %d/%m/%Y"),
                                timestamps[timestamp]['essAirTemperature.0'],
                                timestamps[timestamp]['essSurfaceTemperature.1'],
                                ))
            except KeyError:
                raise web.notfound()
        return vao + "\n".join(lines)
  


class ObsGraph:
    def GET(self, version=1):
        if not check_auth():
            return authenticate()
        stnid = web.input().stnid
        SQL = """SELECT st.station_name as Name, dv.stn_id as id, st.lat, st.lon, dv.sensor_id, dv.creationtime as time,se.symbol, dv.nvalue as value
                 FROM oe.data_value dv, oe.sensor_identity se, oe.station_identity st
                 WHERE dv.stn_id = $stnid
                 AND st.stn_id = dv.stn_id
                 AND se.stn_id = dv.stn_id
                 AND se.symbol in ('01' , '03', 'essDewpointTemp.0', 'essAirTemperature.1', 'essSurfaceTemperature.1', 'spectroSurfaceTemperature.1', '30', '60')
                 AND dv.sensor_id = se.sensor_id
                 AND dv.status > -1
                 AND dv.creationtime > now() - '24 hours'::interval
                 ORDER BY dv.creationtime ASC;"""
        rows = db['clouddb'].query(SQL, {'stnid': stnid, })
        if not rows:
            raise web.notfound()
        row = rows[0]
        result = {'Name': row['name'], 'id': row['id'], 'lat': row['lat'], 'lon': row['lon'], 'results': []}
        result['results'].append({'time': row['time'].strftime("%Y-%m-%d %H:%M:%S"),
                                  'symbol': row['symbol'],
                                  'value': row['value']})
        for row in rows:
            result['results'].append({'time': row['time'].strftime("%Y-%m-%d %H:%M:%S"),
                                      'symbol': row['symbol'],
                                      'value': row['value']})
        web.header('Content-Type', 'application/json')
        return json.dumps(result)

class Roles:
    def GET(self, version=1):
        if not check_auth():
            return authenticate()
        user = web.input().uname
        SQL = """SELECT ur.role,
                   ur.role_description,
                   ur.fcast_region_id AS fc_id,
                   ur.metar_data AS metarData,
                   ur.ltg_data as ltgData,
                   ur.graph_data as graphData,
                   ur.country_code as countryID,
                   ur.ticker as ticker,
                   ur.bounds as bounds
                 FROM users us, newer_tomcat_roles ur 
                 WHERE us.username = ur.username 
                 AND us.username = $user;"""
        result = {'user': user, 'list': []}
        rows = db['authdb'].query(SQL, {'user': user})
        for row in rows:
            result['list'].append({"role_description": row.role_description,
                                   "role": row.role,
                                   "fc_id": row.fc_id,
                                   "metarData": row.metardata,
                                   "ltgData": row.ltgdata,
                                   "ticker": row.ticker,
                                   "countryID": row.countryid,
                                   "graphData": row.graphdata,
                                   "bounds": row.bounds})
        web.header('Content-Type', 'application/json')
        return json.dumps(result)

class LightningPoint:
    def GET(self, version=1):
        if not check_auth():
            return authenticate()
        user_data = web.input(miles=None)
        lat = user_data.lat
        lon = user_data.lon
        if user_data.miles == "5":
            SQL = "select * from realtime.get_ltg_for_point_five($lat, $lon)"
        else:
            SQL = "select * from realtime.get_ltg_for_point($lat, $lon)"
        rows = db['lightningdb'].query(SQL, {'lat': lat, 'lon': lon})
        row = rows[0]
        result = {'lat': lat,
                  'lon': lon,
                  'closest_strike': str(row['v_strike_dist_all'])
                  }
        if user_data.miles == "5":
            result['num_strikes_within_5'] = str(row['v_no_strike_five'])
        else:
            result['num_strikes_within_7'] = str(row['v_no_strike_seven'])
            result['num_strikes_within_20'] = str(row['v_no_strike_twenty'])
        web.header('Content-Type', 'application/json')
        return json.dumps(result)


def latest_files(directory, number=1):
    filelist = sorted(os.listdir(directory)) #catching directory not existing in ListRadar
    filelist = [x for x in filelist if x.endswith('.png')]
    return filelist[-number:]

def radar_metadata(radarpath):
    try:
        with open(radarpath + '/.bounds') as f:
            metadata = json.load(f)
    except IOError:
        return None
    try:
        bounds = {'left': float(metadata['bounds']['left']),
                  'right': float(metadata['bounds']['right']),
                  'top': float(metadata['bounds']['top']),
                  'bottom': float(metadata['bounds']['bottom']),
                 }
        dimensions = [int(metadata['dimensions'][0]),
                      int(metadata['dimensions'][1])
                     ]
    except KeyError:
        return None
    return bounds, dimensions

def set_url_scheme(url):
    if url is None:
        return url
    url = list(urlsplit(url))
    https = web.ctx.env.get('HTTP_X_FORWARDED_PROTO', None)
    if https:
        url[0] = https
    return urlunsplit(url)

def www_domain():
    domain = urlparse(web.ctx['homedomain'])
    if domain.netloc[:4] == 'api.':
        domain = domain.scheme + '://www.' + domain.netloc[4:]
    else:
        domain = domain.scheme + '://' + domain.netloc
    return set_url_scheme(domain)
   

def radar_json(radardir):
    domain = www_domain()
    number = int(web.input(imgno=1).imgno)
    radarpath = '/var/www/html/' + radardir
    image_sequence = latest_files(radarpath, number)
    bounds, dimensions = radar_metadata(radarpath)
    return json.dumps({'radar_url': urljoin(domain, radardir),
                       'image_sequence': image_sequence,
                       'bounds': bounds,
                       'dimensions': dimensions})
    
class ListRadar:
    def GET(self, version=1, countryID=None):
        if not re.match("^[A-Za-z0-9]+$", countryID):
            raise web.notfound()
        directory = 'radar/' + countryID.lower()
        web.header('Content-Type', 'application/json')
        try:
            return radar_json(directory)
        except OSError: #if directory doesn't exist
            raise web.notfound()
    
class Nagios:
    def GET(self, version=1):
        targetdb = web.input(db="cloud").db
        if targetdb == "cloud":
            latest = db['clouddb'].select('oe.data_value',
                                          what="max(created)")[0].max
            delta = timedelta(minutes=5)
        elif targetdb == "metar":
            latest = db['metardb'].select('oe.data_value',
                                          what="max(created)")[0].max
            delta = timedelta(minutes=10)
        elif targetdb == "madis":
            latest = db['madisdb'].select('oe.data_value',
                                          what="max(created)")[0].max
            delta = timedelta(minutes=65)
        else:
            raise web.notfound()
        web.header('check_http',"Throws a strop if there aren't any headers")
        if datetime.utcnow() - delta < latest:
            return "OK!! %s" % latest
        else:
            return "ERROR!! %s" % latest

alertCategories = { 'AFY': 'Ashfall Advisory',
                    'ASY': 'Air Stagnation Advisory',
                    'BSY': 'Blowing Snow Advisory',
                    'BWY': 'Brisk Wind Advisory',
                    'BZA': 'Blizzard Watch',
                    'BZW': 'Blizzard Warning',
                    'CFA': 'Coastal Flood Watch',
                    'CFS': 'Coastal Flood Statement',
                    'CFW': 'Coastal Flood Warning',
                    'CFY': 'Coastal Flood Advisory',
                    'DSW': 'Dust Storm Warning',
                    'DUY': 'Blowing Dust Advisory',
                    'ECA': 'Extreme Cold Watch',
                    'ECW': 'Extreme Cold Warning',
                    'EHA': 'Excessive Heat Watch',
                    'EHW': 'Excessive Heat Warning',
                    'EWW': 'Severe Weather Statement|Extreme Wind Warning',
                    'FAA': 'Areal Flood Watch',
                    'FAW': 'Flood Warning (areal)',
                    'FAY': 'Arroyo and Small Stream Flood Advisory|Hydrologic Advisory|Small Stream Flood Advisory|Urban and Small Stream Flood Advisory|Flood Advisory (areal)',
                    'FFA': 'Flash Flood Watch',
                    'FFW': 'Flash Flood Statement|Flash Flood Warning',
                    'FGY': 'Dense Fog Advisory',
                    'FLA': 'Flood Watch for Forecast Points',
                    'FLW': 'Flood Statement (follow-up to point Flood Warning)|Flood Warning (for forecast points)',
                    'FLY': 'Flood Advisory (for forecast points)',
                    'FRY': 'Frost Advisory',
                    'FWA': 'Fire Weather Watch',
                    'FWW': 'Red Flag Warning (fire weather)',
                    'FZA': 'Freeze Watch',
                    'FZW': 'Freeze Warning',
                    'GLA': 'Gale Watch',
                    'GLW': 'Gale Warning',
                    'HCW': 'Hurricane Watch / Warning',
                    'HFA': 'Hurricane Force Wind Watch',
                    'HFW': 'Hurricane Force Wind Warning',
                    'HIA': 'Hurricane Wind Watch|Inland Hurricane Watch',
                    'HIW': 'Hurricane Wind Warning|Inland Hurricane Warning',
                    'HSW': 'Heavy Snow Warning',
                    'HTY': 'Heat Advisory',
                    'HUA': 'Hurricane Watch',
                    'HUW': 'Hurricane Warning',
                    'HWA': 'High Wind Watch',
                    'HWO': 'Hazardous Weather Outlook',
                    'HWW': 'High Wind Warning',
                    'HYS': 'Hydrologic Statement (for non-flood points)',
                    'HZA': 'Hard Freeze Watch',
                    'HZW': 'Hard Freeze Warning',
                    'IPW': 'Sleet Warning',
                    'IPY': 'Sleet Advisory',
                    'ISW': 'Ice Storm Warning',
                    'LBY': 'Lake Effect Snow and Blowing Snow Advisory',
                    'LEA': 'Lake Effect Snow Watch',
                    'LEW': 'Lake Effect Snow Warning',
                    'LEY': 'Lake Effect Snow Advisory',
                    'LOY': 'Low Water Advisory',
                    'LSA': 'Lakeshore Flood Watch',
                    'LSS': 'Lakeshore Flood Statement',
                    'LSW': 'Lakeshore Flood Warning',
                    'LSY': 'Lakeshore Flood Advisory',
                    'LWY': 'Lake Wind Advisory',
                    'MAF': 'Routine Marine (no hazards in effect)',
                    'MAS': 'Marine Weather Statement (non follow-up) ',
                    'MAW': 'Marine Weather Statement (follow-up to SMW)|Special Marine Warning',
                    'RBY': 'Small Craft Advisory for Rough Bar',
                    'SBY': 'Snow and Blowing Snow Advisory',
                    'SCY': 'Small Craft Advisory',
                    'SEA': 'Hazardous Seas Watch',
                    'SEW': 'Hazardous Seas Warning',
                    'SIY': 'Small Craft Advisory for Winds',
                    'SMY': 'Dense Smoke Advisory',
                    'SNY': 'Snow Advisory',
                    'SPS': 'Special Weather Statement',
                    'SRA': 'Storm Watch',
                    'SRW': 'Storm Warning|Storm Warning (marine)',
                    'SUW': 'High Surf Warning',
                    'SUY': 'High Surf Advisory',
                    'SVA': 'Severe Thunderstorm Watch',
                    'SVW': 'Severe Weather Statement|Severe Thunderstorm Warning',
                    'SWY': 'Small Craft Advisory for Hazardous Seas',
                    'TIA': 'Inland Tropical Storm Watch|Tropical Storm Wind Watch',
                    'TIW': 'Inland Tropical Storm Warning|Tropical Storm Wind Warning',
                    'TOA': 'Tornado Watch',
                    'TOW': 'Severe Weather Statement|Tornado Warning',
                    'TRA': 'Tropical Storm Watch',
                    'TRW': 'Tropical Storm Warning',
                    'TSA': 'Tsunami Watch',
                    'TSW': 'Tsunami Warning',
                    'TWW': 'Tornado Watch',
                    'TYA': 'Typhoon Watch',
                    'TYW': 'Typhoon Warning',
                    'UPA': 'Heavy Freezing Spray Watch',
                    'UPW': 'Heavy Freezing Spray Warning',
                    'UPY': 'Freezing Spray Advisory',
                    'WCA': 'Wind Chill Watch',
                    'WCW': 'Wind Chill Warning',
                    'WCY': 'Wind Chill Advisory',
                    'WIY': 'Wind Advisory',
                    'WSA': 'Winter Storm Watch',
                    'WSW': 'Winter Storm Warning',
                    'WWY': 'Winter Weather Advisory',
                    'ZFY': 'Freezing Fog Advisory',
                    'ZRY': 'Freezing Rain Advisory'
                   }

class alertPoly:
    def GET(self, version=1):
        if not check_auth():
            return authenticate()
        i = web.input(left=None, right=None, top=None, bottom=None, state=None, county=None, lat=None, lon=None, alertCat=[], singlepoint=False, simplify=False, sqldebug=False)
        if not (i.left and i.right and i.top and i.bottom) and not i.state and not (i.lat and i.lon):
            raise web.notfound("specify some sort of parameter")
        vars = {}
        tolerance = False
        try:
            if i.simplify:
                tolerance = float(i.simplify)
        except ValueError:
            pass
        SQL = """SELECT d.text, d.alertcategory, d.vtec, d.exptime, d.ugcstring"""
        if i.singlepoint and i.singlepoint != "false":
            SQL += """, ST_AsGeoJSON( ST_PointOnSurface(d.geom) ) as geom """
        elif tolerance:
            SQL += """, ST_AsGeoJSON( ST_Simplify(d.geom,$tolerance) ) as geom """
            vars['tolerance'] = tolerance
        else:
            SQL += """, ST_AsGeoJSON( d.geom ) as geom """
        SQL += """FROM dynamic.nwsalerts d """
        firstwhere = True
        if i.state:
            vars['state'] = i.state
            vars['stateregex'] = '%s(Z|C)' % i.state
            if i.county:
                vars['county'] = i.county
                SQL += """, static.uscounties c
                          WHERE ST_Intersects(d.geom, c.geom) -- This next line looks stupid... but we're relying on rounding errors.
                            AND ST_Touches(ST_GeomFromGeoJSON(ST_AsGeoJSON(d.geom)), ST_GeomFromGeoJSON(ST_AsGeoJSON(c.geom)))=FALSE
                            AND c.state=$state
                            AND c.countyname=$county"""
            else:
                SQL += """, static.usstates s
                          WHERE d.ugcstring ~ $stateregex
                            AND ST_Touches(d.geom, s.geom)=FALSE
                            AND s.state=$state"""
            firstwhere = False
        else:
            SQL += """ WHERE """

        if (i.left and i.right and i.top and i.bottom):
            if not firstwhere:
                SQL += """ AND """
            SQL += """ ST_Intersects(ST_PolygonFromText('POLYGON(($right $top,$left $top,$left $bottom,$right $bottom,$right $top))'), d.geom)"""
            for param in 'left', 'right', 'top', 'bottom':
                vars[param] = float(i[param])
        
        if (i.lat and i.lon):
            if not firstwhere:
                SQL += """ AND """
            SQL += """ ST_Intersects(ST_PointFromText('POINT($lon $lat)'), d.geom) """
            for param in 'lat', 'lon':
                vars[param] = float(i[param])
        if i.alertCat:
            SQL += """ AND d.alertcategory in $alertcategories """
            vars['alertcategories'] = i.alertCat

        SQL += """ order by d.ugcstring asc """

        result = db['weatherzones'].query(SQL, vars=vars, _test=bool(i.sqldebug))
        if i.sqldebug:
            return result
        payload = []
        for alerts in result:
            alert = json.loads(alerts.geom)
            alert['alert'] = alerts.text
            alert['alertCategory'] = alerts.alertcategory
            if alerts.alertcategory in alertCategories:
                alert['alertCategoryName'] = alertCategories[alerts.alertcategory]
            else:
                alert['alertCategoryName'] = alerts.alertcategory
            alert['ugcstring'] = alerts.ugcstring
            if alerts.vtec:
                alert['vtec'] = alerts.vtec
            else:
                alert['vtec'] = None
            alert['vtecBeginTime'] = None
            alert['vtecEndTime'] = None
            m = re.search('\/O\.\w{3}\.\w{4}\.\w{2}\.\w\.\d*\.(?P<start>[^\-]*)\-(?P<end>[^\/]*)\/', alerts.vtec or '')
            if m:
                vtecBeginTime = m.group('start')
                vtecEndTime = m.group('end')
                if not vtecBeginTime[0:2] == "00":
                    alert['vtecBeginTime'] = datetime.strptime(vtecBeginTime, '%y%m%dT%H%MZ').strftime("%Y-%m-%dT%H:%M:%SZ")
                if not vtecEndTime[0:2] == "00":
                    alert['vtecEndTime'] = datetime.strptime(vtecEndTime, '%y%m%dT%H%MZ').strftime("%Y-%m-%dT%H:%M:%SZ")
            if version == "1": # TODO: Deprecate v1
                alert['alertUGCexpirationTime'] = datetime.fromtimestamp(alerts.exptime).strftime("%Y-%m-%dT%H:%M:%SZ")
            else:
                alert['alertUgcExpirationTime'] = datetime.fromtimestamp(alerts.exptime).strftime("%Y-%m-%dT%H:%M:%SZ")
            payload.append(alert)
        web.header('Content-Type', 'application/json')
        return json.dumps(payload)


if __name__ == "__main__":
    web.config.debug = True
    app.run()
else:
    for d in db.keys():
        db[d].printing = False
    web.config.debug = False
    web.config.debug_sql = False
    application = app.wsgifunc()
