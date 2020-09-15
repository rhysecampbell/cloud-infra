#!/usr/bin/env python
#FORMAT PYTHON

"""Provide html tables for stations & regions."""

import web
import logging
import os

from app.common.common import is_test, InjectingFilter, get_httpauth, lastget
from app.common.common import debug, debug_sql
from app.common.dqmpg import session
from datetime import datetime, timedelta

URLS = (
  '/stationtable.html', 'StationTable',
  '/regiontable.html', 'RegionTable',
)

APP = web.application(URLS, globals(), autoreload=False)

CURDIR = os.path.dirname(__file__)
RENDER = web.template.render(os.path.join(CURDIR, 'templates'))

logfilter = InjectingFilter()
log = logging.getLogger('app.tables')
log.addFilter(logfilter)

web.config.debug = debug
web.config.debug_sql = debug_sql


class StationTable:
    def GET(self):
        i = web.input(station=None, earliesttime=None, latesttime=None)
        username, password = get_httpauth()
        object = session(username, password, None, i.station, 'table')
        if not i.earliesttime or not i.latesttime:
            i.earliesttime = datetime.now() - timedelta(days=1)
            i.latesttime = datetime.now() + timedelta(minutes=5)
        data = object.data(i.earliesttime, i.latesttime, lastget())
        finaldata, sensortable = data.vai_crosstab()
        web.header('Content-Type', 'text/html; charset=utf-8')
        return RENDER.stationtable(data.stations, finaldata, sensortable,)


class RegionTable:
    def GET(self):
        i = web.input(region=None, earliesttime=None, latesttime=None)
        username, password = get_httpauth()
        object = session(username, password, i.region, None, 'table')
        data = object.data(i.earliesttime, i.latesttime, lastget())
        finaldata, sensortable = data.vai_crosstab()
        web.header('Content-Type', 'text/html; charset=utf-8')
        return RENDER.regiontable(data.stations, finaldata, sensortable,)


application = APP.wsgifunc()
if (not is_test()) and __name__ == "__main__":
    web.config.debug_sql = True
    web.config.debug = True
    logging.basicConfig(level=logging.DEBUG,
                    format='%(asctime)s %(process)d %(thread)d ' \
                           '%(levelname)s: %(ip)s %(method)s %(path)s ' \
                           '%(name)s %(message)s',
                    datefmt='%Y%m%dT%H%M%S')
    APP.run()
