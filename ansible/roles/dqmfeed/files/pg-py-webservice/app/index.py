#!/usr/bin/env python
#FORMAT PYTHON

"""Provides legacy urls from / now normally housed in subdirectory"""

import web
import logging

from app.common.common import is_test, get_httpauth, InjectingFilter
from app.common.vaipg import check_password

URLS = (
  '/', 'Index',
  '/export', 'VaisalaObs',
  '/jpglist.html', 'ListJpg',
)

APP = web.application(URLS, globals(), autoreload=False)

logfilter = InjectingFilter()
log = logging.getLogger('app.index')
log.addFilter(logfilter)


class Index:
    """Generic support for accessing /"""
    def GET(self):
        """Authenticate then return help."""
        check_password(*get_httpauth())
        web.header('Content-Type', 'text/html; charset=utf-8')
        return "<body>If you don't know how to use this site and believe " \
               "that you should, please contact " \
               "ice.technical.support@vaisala.com</body>"

application = APP.wsgifunc()

if (not is_test()) and __name__ == "__main__":
    web.config.debug_sql = True
    web.config.debug = True
    APP.run()
