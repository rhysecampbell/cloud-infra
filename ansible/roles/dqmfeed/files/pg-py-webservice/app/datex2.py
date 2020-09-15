#!/usr/bin/env python
#FORMAT PYTHON
import web
import logging
import os

from app.common.common import InjectingFilter, is_test, dbconfig, get_httpauth
from app.common.common import lastget, debug, debug_sql, dbprinting
from app.common.dqmpg import session

CURDIR = os.path.dirname(__file__)
RENDER = web.template.render(os.path.join(CURDIR, 'templates'))

db = web.database(**dbconfig)

db.printing = dbprinting
web.config.debug = debug
web.config.debug_sql = debug_sql

URLS = (
  '/content.xml', 'Data',
  '/mst.xml', 'Mst',
)

APP = web.application(URLS, globals(), autoreload=False)

logfilter = InjectingFilter()
log = logging.getLogger('app.datex2')
log.addFilter(logfilter)


class Data:
    def GET(self):
        i = web.input(region=None, station=None,
                      earliesttime=None, latesttime=None)
        # TODO: If no earliest/latest-time, use web.modified?
        username, password = get_httpauth()
        object = session(username, password, i.region, i.station, 'datex2')
        data = object.data(i.earliesttime, i.latesttime, lastget())
        ## TODO: Mark data as faulty based on value_status
        web.header('Content-Type', 'text/xml; charset=utf-8')
        return data.datex2()


class Mst:
    def GET(self):
        # FIXME: MST's should be separated by region. id'd by region.
        i = web.input(region=None, station=None,
                      earliesttime=None, latesttime=None)
        username, password = get_httpauth()
        object = session(username, password, i.region, i.station, 'datex2')
        mst = object.mst()
        web.header('Content-Type', 'text/xml; charset=utf-8')
        return mst.xml()
        # TODO: No 304's now?
        # FIXME: Need to compare timestamp on template or update on upgrade


application = APP.wsgifunc()
if (not is_test()) and __name__ == "__main__":
    # Ok lets run the builtin webserver..
    web.config.debug_sql = True
    web.config.debug = True
    logging.basicConfig(level=logging.DEBUG,
                        format='%(asctime)s %(process)d %(thread)d ' \
                               '%(levelname)s: %(ip)s %(method)s %(path)s ' \
                               '%(name)s %(message)s',
                        datefmt='%Y%m%dT%H%M%S')
    APP.run()
