#!/usr/bin/env python
#FORMAT PYTHON

"""The main application, runnable on its own or under mod_wsgi."""

import os
import sys
import web
import logging.config

#Required for mod_wsgi in a random folder.
CURDIR = os.path.dirname(__file__)
if CURDIR not in sys.path:
    sys.path.append(CURDIR)

logging_config_path = os.path.abspath(os.path.join(CURDIR, "logging.conf"))
logging.config.fileConfig(logging_config_path)

from app.common.common import is_test, debug, debug_sql
web.config.debug = debug
web.config.debug_sql = debug_sql

import app.index  # @UnusedImport
import app.vaisalaobs
import app.datex2
import app.admin
import app.tables

MAPPING = (
    '/', 'app.index.Index',
    '/jpglist.html', 'app.vaisalaobs.ListJpg',
    '/datex2', app.datex2.APP,
    '/export', app.vaisalaobs.APP,
    '/admin', app.admin.APP,
    '/table', app.tables.APP
)

APP = web.application(MAPPING, globals(), autoreload=False)

application = APP.wsgifunc()

if (not is_test()) and __name__ == "__main__":
    web.config.debug_sql = True
    web.config.debug = True
    APP.run()
