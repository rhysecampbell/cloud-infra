#!/usr/bin/env python
#FORMAT PYTHON
'''
Created on 19 Apr 2012

@author: JPC
'''

import web
import logging
import os

from datetime import datetime
from app.common.common import InjectingFilter, getconfig
from app.common.datex2 import Island as preIsland

CURDIR = os.path.dirname(__file__)
RENDER = web.template.render(os.path.join(CURDIR, 'app', 'templates'))

PGDB = web.database(**getconfig('postgres'))

## Set to true later on for builtin server...
web.config.debug_sql = False
web.config.debug = False

logfilter = InjectingFilter()
log = logging.getLogger('app.datex2')
log.addFilter(logfilter)


class Island(preIsland):
    def authn(self):
        """
        Overwrite to hardwrite parameters
        """
        """Authenticate username & password from get_httpauth else raise 401"""
        username, password = "jpc", "pirates"
        log.debug("username=%s" % (username))
        if self.check_password(username, password, ):
            log.debug("username=%s authn=success" % (username))
            return username
        else:
            log.info("username=%s authn=failure" % (username))
            web.header("WWW-Authenticate", 'Basic realm="Vaisala Data Export"')
            web.header('Content-Type', 'text/html; charset=utf-8')
            raise web.HTTPError("401 unauthorized", {}, \
                                "Please use a valid username & password.")


island = Island(PGDB)

i = {'station': 13,
     'username': 'jpc',
     'password': 'pirates',
     'region': None,
     'earliesttime': None,
     'latesttime': None,
     'cam': None
     }

username = island.authn()
region, vmdb_id = island.authz(username, "datex2", i['region'], i['station'])
log.info('Datex2Data region=%s station=%s' % (region, vmdb_id))
result, stations = island.data(vmdb_id=vmdb_id, region_id=region,
                               earliesttime=i['earliesttime'],
                               latesttime=i['latesttime'])
data = island.crosstab(result)
datex2index = {}
if len(stations) == 1:
    station_version = {0: island.get_mst_date(vmdb_id)}
else:
    station_version = {0: island.get_mst_date(), }
for vmdb_id in stations:
    datex2index[vmdb_id] = island.get_datex2index_groups(vmdb_id)
    station_version[vmdb_id] = island.get_mst_date(vmdb_id)
## TODO: Mark data as faulty based on value_status
RENDER.datex2(stations, data,
              datetime.utcnow().strftime('%Y-%m-%dT%H:%M:%S+00:00'),
              datex2index, station_version)
