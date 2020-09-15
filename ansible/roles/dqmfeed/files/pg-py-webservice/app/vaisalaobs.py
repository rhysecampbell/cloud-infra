#!/usr/bin/env python
#FORMAT PYTHON

"""Provide exports in vaisala observation xml format."""

import web
import logging
import os

from app.common.common import is_test, InjectingFilter, get_httpauth
from app.common.common import lastget, debug, debug_sql
from app.common.dqmpg import session

URLS = (
  '', 'VaisalaObs',
  '/vaisalaobs.xml', 'VaisalaObs',
  '/jpglist.html', 'ListJpg',
  '/image.jpg', 'Jpg',
  '/qttntcipobs.xml', 'VaisalaObs',
)

APP = web.application(URLS, globals(), autoreload=False)

CURDIR = os.path.dirname(__file__)
RENDER = web.template.render(os.path.join(CURDIR, 'templates'))

logfilter = InjectingFilter()
log = logging.getLogger('app.vaisalaobs')
log.addFilter(logfilter)

web.config.debug = debug
web.config.debug_sql = debug_sql


class VaisalaObs:
    def GET(self):
        i = web.input(region=None, station=None,
                      earliesttime=None, latesttime=None, cam=1)
        username, password = get_httpauth()
        if web.ctx.path == '/qttntcipobs.xml':
            role = 'qtt'
        else:
            role = 'xml'
        object = session(username, password, i.region, i.station, role)
        data = object.data(i.earliesttime, i.latesttime, lastget())
        web.header('Content-Type', 'text/xml; charset=utf-8')
        if role == 'xml':
            return data.vaisalaobs()
        elif role == 'qtt':
            return data.qttntcipobs()


class Jpg:
    def GET(self):
        i = web.input(region=None, station=None, latesttime=None, cam=1)
        username, password = get_httpauth()
        object = session(username, password, None, i.station, role='jpg')
        if not i.station:
            web.header('Content-Type', 'text/html; charset=utf-8')
            raise web.HTTPError("403 forbidden", {},
                                "Please specify a station.")
        web.header('Content-Type', 'image/jpeg')
        return object.jpg(i.cam, i.latesttime)


class ListJpg:
    def GET(self):
        i = web.input(region=None, station=None, cam=None)
        username, password = get_httpauth()
        object = session(username, password, None, i.station, role='jpg')
        if not i.station:
            web.header('Content-Type', 'text/html; charset=utf-8')
            raise web.HTTPError("403 forbidden", {},
                                "Please specify a station.")
        object.lastupdate('jpg')
        web.header('Content-Type', 'text/html; charset=utf-8')
        return RENDER.jpglist(object.jpglist(), i.station)

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
