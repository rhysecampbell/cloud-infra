#!/usr/bin/env python

import re
import os
import web
import json
import ConfigParser

from urlparse import urlparse
from datetime import datetime, timedelta
from base64 import b64decode
from urlparse import urljoin
from os.path import split as pathsplit

config = ConfigParser.RawConfigParser()
config.read('/etc/vaisala-config/settserver.cfg')
noauthsecret = config.get('general', 'noauthsecret')
secretusername = config.get('general', 'username')
secretpassword = config.get('general', 'password')
avicastusername = config.get('general', 'avicast_username')
avicastpassword = config.get('general', 'avicast_password')
avicastregionid = config.get('general', 'avicast_regionid')
credentials = ((secretusername, secretpassword), (avicastusername, avicastpassword))
db = {}
for d in 'dqmdb', 'dqmidb':
    params = dict((p, config.get(d, p)) for p in ['dbn', 'database', 'host', 'port', 'user', 'password'])
    params['pooling'] = False
    db[d] = web.database(**params)

urls = (
        '/api/v(.*)/dqm(Data|Image)/(values|quality|meta)', 'processRequest',
        '/api/(.*)', 'other'
        )

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

regex_period = re.compile('P((?P<days>[0-9]+)D)?((?P<hours>[0-9]+)H)?((?P<minutes>[0-9]+)M)?')

def parse_nih_vaisala_8601_duration(duration, limitdays=False):
    match = re.match(regex_period, duration)
    #period = timedelta(days=int(match.group('days') or 0),
    #                   hours=int(match.group('hours') or 0),
    #                   minutes=int(match.group('minutes') or 0))
    #return period
    if not match:
        raise web.notfound("period must be in format P[#H][##H][##M]")
    days = int(match.group('days') or 0)
    hours = int(match.group('hours') or 0)
    minutes = int(match.group('minutes') or 0)
    if limitdays:
        limitminutes = limitdays*24*60
        interval = days*24*60 + hours*60 + minutes
        if interval > limitminutes:
            raise web.notfound("period must be less than 7 days") #FIXME: Does this work?
    interval = '%i days %i hours %i minutes' % (days, hours, minutes)
    return interval

class other:
    def GET(self, other):
        return other

def observation(requesttype, store, currentstation, currentstationname, currentdataset, currentxmltargetname, row):
    if requesttype == 'meta':
        result = {'stationId': currentstation,
                  'stationName': currentstationname,
                  'lat': row['lat'],
                  'lon': row['lon'],
                  'xmlTargetName': currentxmltargetname
           }
        if store == 'Image':
            result.update({'cameraData': currentdataset,
                           'country': row['country_id'],
                           'regionName': row['v_region_name'],
                           'regionDisplayName': row['display_name'],
                           'regionId': row['owning_region_id']
                          })
        elif store == 'Data':
            result.update({'codeSpace': row['codespace'],
                           'sensorData': currentdataset
                           })
    else:
        result = {'stationId': currentstation,
                  'stationName': currentstationname,
                  'dataSet': currentdataset,
                  'xmlTargetName': currentxmltargetname
                   }
    return result


class processRequest:
    def GET(self, version, store, requesttype):
        i = web.input(stationId=None, noauth=None, period=None, offset=None, regionid=None, regionId=None, queryMode=None, geo=None, exactTime=None, sqldebug=False, prettyjson=False)
        username, password = None, None
        if i.noauth == noauthsecret:
            pass
        else:
            try:
                username, password = b64decode(web.ctx.env['HTTP_AUTHORIZATION'][6:]).split(':')
            except KeyError:
                return authenticate()
            if (username, password) in credentials: # FIXME: better auth
                pass
            else:
                return authenticate()
        if not i.regionId:
            i.regionId = i.regionid # FIXME: DQM doesn't respect case

        variables = {}

        if not (i.stationId or i.regionId or i.geo):
            raise web.notfound("Specify a stationId, regionId or geo")

        if store == 'Data':
            dbconfigname = 'dqmdb'
            if requesttype == 'meta':
                SQL = ["""SELECT st.stn_id, st.xml_target_name,st.station_name,
                                 st.lat, st.lon, st.country_id, st.org_id,
                                 sai.v_region_name, sai.display_name, si.sensor_id,
                                 si.symbol, si.sensor_no, si.codespace,
                                 si.sensor_master_id, st.owning_region_id
                          FROM qm.station_identity st, qm.sensor_identity si,
                               qm.station_alias sa, qm.station_alias_identity sai"""]
            else:
                SQL = ["""SELECT v.obs_creationtime as ts, v.db_insertiontime,
                                 st.station_name, st.stn_id, si.symbol, si.sensor_no,
                                 st.owning_region_id, st.lat, st.lon, v.sensor_id,
                                 st.xml_target_name,"""]
                if requesttype == 'values':
                    SQL.append("""     nvalue, v.qc_check_total AS qctotal, qc_check_failed as qcfailed
                                  FROM qm.data_value v, qm.sensor_identity si,
                                       qm.station_identity st, qm.station_alias sa""")
                elif requesttype == 'quality':
                    SQL.append("""     v.test_type, v.status, v.uncertancy
                                  FROM qm.data_quality v, qm.sensor_identity si,
                                       qm.station_identity st, qm.station_alias sa""")
        elif store == 'Image':
            dbconfigname = 'dqmidb'
            if requesttype == 'meta':
                SQL = ["""SELECT st.station_name, id.image_target_name,
                                 id.dqm_xml_target_name as xml_target_name, id.cam_no,
                                 id.dqm_country_id as country_id, id.dqm_stn_id as stn_id,
                                 id.dqm_lat as lat, id.dqm_lon as lon, id.cat_id,
                                 sai.display_name, sai.v_region_name, st.owning_region_id
                          FROM qm.station_alias sa, qm.identity id,
                               qm.station_identity st, qm.station_alias_identity sai"""]
            else:
                SQL = ["""SELECT st.station_name, v.mes_datetime AS \"ts\",
                                 v.entry_datetime::timestamp, v.stn_id,
                                 v.cam_no, v.raw_image_size, v.image_detail,
                                 v.image_mean, v.image_variance,
                                 v.image_status, id.image_target_name,
                                 id.dqm_xml_target_name AS xml_target_name, id.dqm_stn_id"""]
                if requesttype == 'values':
                    SQL.append(""",encode(v.image,'base64') AS \"image\",
                                  encode(v.thumb,'base64') AS \"thumb\",
                                  encode(v.icon,'base64') AS \"icon\" """)
                SQL.append("""FROM qm.roadimage v, qm.station_alias sa,
                                   qm.identity id, qm.station_identity st""")
        if requesttype == 'meta':
            SQL.append("""WHERE true""")
        else:
            if store == 'Data':
                insertiontimename = 'db_insertiontime'
            elif store == 'Image':
                insertiontimename = 'entry_datetime'
            if i.queryMode == 'creationTime':
                querymode = 'creationTime'
                if store == 'Data':
                    SQL.append("""where v.obs_creationtime""")
                elif store == 'Image':
                    SQL.append("""where v.mes_datetime""")
            else:
                querymode = 'insertionTime'
                if store == 'Data':
                    SQL.append("""where v.db_insertiontime""")
                elif store == 'Image':
                    SQL.append("""where v.entry_datetime""")

            if i.period:
                variables['period'] = parse_nih_vaisala_8601_duration(i.period, 7)
            else:
                variables['period'] = '15 minutes'

            if i.exactTime:
                variables['exactTime'] = i.exactTime
                SQL.append("""between timestamp $exactTime - interval $period and $exactTime """)
            else:
                if i.offset:
                    variables['offset'] = parse_nih_vaisala_8601_duration(i.offset)
                else:
                    variables['offset'] = '0 minutes'
                SQL.append("""between now() - interval $offset - interval $period
                              and now() - interval $offset """)
        
        if i.geo:
            variables['xmin'], variables['ymin'], variables['xmax'], variables['ymax'] = i.geo.split(',')
            SQL.append("""and st.geom && ST_MakeEnvelope($xmin, $ymin, $xmax, $ymax, 4326)""")
        
        if i.stationId:
            variables['xml_target_name'] = i.stationId
            if store == 'Image':
                SQL.append("""and id.dqm_xml_target_name = $xml_target_name""")
            else:
                SQL.append("""and st.xml_target_name = $xml_target_name""")

        if i.regionId:
            variables['v_region_id'] = i.regionId
            SQL.append("""and sa.v_region_id = $v_region_id""")

        if username == avicastusername:
            if not store == 'Data':
                raise web.notfound("Your account is only authorized for data.")
            SQL.append("""and sa.v_region_id = $avicastregionid""")
            variables['avicastregionid'] = avicastregionid

        if store == 'Data':
            SQL.append("""and sa.stn_id = st.stn_id""")
            if requesttype == 'meta':
                SQL.append("""and sai.v_region_id = sa.v_region_id
                              and si.stn_id = st.stn_id
                              and sa.stn_id = st.stn_id
                              order by st.stn_id;""")
            else:
                if requesttype == 'values':
                    SQL.append("""and v.stn_id = st.stn_id """)
                if requesttype == 'quality':
                    SQL.append("""and si.stn_id = st.stn_id""")
                SQL.append("""and v.sensor_id = si.sensor_id
                              order by (st.stn_id, v.obs_creationtime) asc;""")
        elif store == 'Image':
            if requesttype == 'meta':
                SQL.append("""and id.dqm_stn_id = sa.stn_id
                              and id.dqm_stn_id = st.stn_id
                              and sai.v_region_id = sa.v_region_id
                              and id.dqm_xml_target_name = st.xml_target_name;""")
            else:
                SQL.append("""and v.stn_id = sa.stn_id 
                              and id.dqm_stn_id = sa.stn_id
                              and id.cam_no = v.cam_no
                              and id.dqm_stn_id = st.stn_id
                              and id.dqm_xml_target_name = st.xml_target_name
                              order by (sa.stn_id, v.mes_datetime) asc;""")

        if i['sqldebug']:
            return db[dbconfigname].query('\n'.join(SQL), vars=variables, _test=True)
        dbresult = db[dbconfigname].query(' '.join(SQL), vars=variables)
        result = {}
        if store == 'Data':
            stationloopname = 'observations'
        elif store == 'Image':
            stationloopname = 'images'
        if requesttype == 'meta':
            stationloopname = 'metaData'
        else:
            result = {"queryMode": querymode}
        if requesttype == 'quality':
            stationloopname = 'quality'
        result[stationloopname] = []

        currentstation = None
        currentstationname = None
        currentxmltargetname = None
        currenttime = None
        latestinsertiontime = datetime(1,1,1)
        currentdataset = []
        currentvalues = []
    
        if not dbresult:
            raise web.notfound('No rows returned')
        for row in dbresult:
            if requesttype != 'meta' and (row['ts'] != currenttime or row['stn_id'] != currentstation):
                if currenttime is not None:
                    currentdataset.append({'time': currenttime.strftime('%Y-%m-%d %H:%M:%S'),
                                           'values': currentvalues})
                currentvalues = []
                currenttime = row['ts']
            if row['stn_id'] != currentstation:
                if currentstation is not None:
                    result[stationloopname].append(observation(requesttype, store, currentstation, currentstationname, currentdataset, currentxmltargetname, row))
                currentdataset = []
                currentstation = row['stn_id']
                currentstationname = row['station_name']
                currentxmltargetname = row['xml_target_name']
            if requesttype == 'meta':
                if store == 'Data':
                    currentdataset.append({'symbol': row['symbol'],
                                           'sensorNo': row['sensor_no'],
                                           'sensorId': row['sensor_id'],
                                           'sensorMasterId': row['sensor_master_id']
                                          })
                elif store == 'Image':
                    currentdataset.append({'imageTargetName': row['image_target_name'],
                                           'cameraNo': row['cam_no'],
                                           'catId': row['cat_id'],
                                          })
            else:
                if store == 'Data':
                    if requesttype == 'values':
                        currentvalues.append({'symbol': row['symbol'],
                                              'sensorNo': row['sensor_no'],
                                              'sensorId': row['sensor_id'],
                                              'nvalue': row['nvalue'],
                                              'qcTotal': row['qctotal'],
                                              'qcFailed': row['qcfailed']
                                             })
                    elif requesttype == 'quality':
                        currentvalues.append({'symbol': row['symbol'],
                                              'sensorNo': row['sensor_no'],
                                              'sensorId': row['sensor_id'],
                                              'status': row['status'],
                                              'testType': row['test_type'],
                                              'uncertancy': row['uncertancy']
                                             })
                elif store == 'Image':
                    if requesttype == 'values':
                        currentvalues.append({'cameraNo': row['cam_no'],
                                              'imageSize': row['raw_image_size'],
                                              'imageDetail': row['image_detail'],
                                              'imageVariance': row['image_variance'],
                                              'imageStatus': row['image_status'],
                                              'imageTargetName': row['image_target_name'],
                                              'image': row['image'],
                                              'thumb': row['thumb'],
                                              'icon': row['icon']
                                             })
                    elif requesttype == 'quality':
                        currentvalues.append({'cameraNo': row['cam_no'],
                                              'imageSize': row['raw_image_size'],
                                              'imageDetail': row['image_detail'],
                                              'imageVariance': row['image_variance'],
                                              'imageMean': row['image_mean'],
                                              'imageStatus': row['image_status'],
                                             })
                if row[insertiontimename] > latestinsertiontime:
                    latestinsertiontime = row[insertiontimename]
        if requesttype == 'meta':
            result[stationloopname].append(observation(requesttype, store, currentstation, currentstationname, currentdataset, currentxmltargetname, row))
            result['regionId'] = row['owning_region_id']
            result['country'] = row['country_id']
            result['regionName'] = row['v_region_name']
            result['regionDisplayName'] = row['display_name']
        else:
            currentdataset.append({'time': currenttime.strftime('%Y-%m-%d %H:%M:%S'),
                                   'values': currentvalues})
            result[stationloopname].append(observation(requesttype, store, currentstation, currentstationname, currentdataset, currentxmltargetname, row))
            if version == '1' and i.stationId:
                # FIXME: Annoyingly the json structure is inconsistent for single station
                # requests. Lets stop doing this in version 2 etc.
                result = result[stationloopname][0]
                result['queryMode'] = querymode
            result['latestInsertTime'] = latestinsertiontime.strftime('%Y-%m-%d %H:%M:%S')
            result['regionId'] = i.regionId if i.regionId else None
            
        web.header('Content-Type', 'application/json')
        if i['prettyjson']:
            response = json.dumps(result, indent=4, separators=(',', ': '))
        else:
            response = json.dumps(result)
        return response


def content_length_processor(handle):
    response = handle()
    if response:
        web.header('Content-Length', len(response))
    return response

app = web.application(urls, globals())
app.add_processor(content_length_processor)
if __name__ == "__main__":
    print "running with debug=True"
    web.config.debug = True
    app.run()
else:
    for d in db.keys():
        db[d].printing = False
    web.config.debug = False
    web.config.debug_sql = False
    application = app.wsgifunc()

# vim: tabstop=8 expandtab shiftwidth=4 softtabstop=4
