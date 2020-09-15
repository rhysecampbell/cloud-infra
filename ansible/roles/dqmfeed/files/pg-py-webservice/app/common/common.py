#!/usr/bin/env python
#FORMAT PYTHON

"""This module provides a basic interface for retrieving iceobs data
from the postgres island system and manipulating it into more usable forms."""

import web
import logging
import os
import ConfigParser
import hashlib

from base64 import b64decode
from random import SystemRandom as sr


class InjectingFilter(logging.Filter):
    def filter(self, record):
        record.ip = web.ctx.ip
        record.path = web.ctx.homepath + web.ctx.fullpath
        record.method = web.ctx.method
        return True


logfilter = InjectingFilter()
log = logging.getLogger('app.common')
log.addFilter(logfilter)


def lastget():
    return web.net.parsehttpdate(web.ctx.env.get('HTTP_IF_MODIFIED_SINCE', '').split(';')[0])


def coord_intstr(coordinate):
    """Fix island system's coordinates. (Add decimal point 6 from right)"""
    # DANGER, Will Robinson! Some longitudes aren't even 6 characters long
    # which causes issues with the obvious(?) approach on negatives.
    # Therefore, lets just pad it to 10 characters and sort it out then.
    if not coordinate:
        # No point going through work converting 0.
        return 0
    if coordinate < 0:
        coordinate = coordinate * -1
        negative = True
    else:
        negative = False
    coordinate_str = str(coordinate).zfill(10)
    coordinate = coordinate_str[:-6] + "." + coordinate_str[-6:]
    coordinate = float(coordinate)
    if negative:
        coordinate = coordinate * -1
    return coordinate


def get_httpauth():
    """
    Return username & password from HTTP_AUTHORIZATION
    headers in web.ctx.env.

    Failing that, try url parameters from web.input.
    """
    try:
        auth = b64decode(web.ctx.env['HTTP_AUTHORIZATION'][6:]).split(':')
        username = auth[0]
        password = auth[1]
        log.debug("authtype=Basic username=%s" % (username))
    except KeyError:
        log.debug("No basic auth, trying parameters")
        try:
            i = web.input(username=None, password=None)
            username = i.username
            password = i.password
            log.debug("authtype=url username=%s" % (username))
        except AttributeError:
            username = None
            password = None
    return username, password


def hashpassword(name, salt, plaintextpassword, n=10):
    if n < 1:
        raise ValueError("n < 1")
    d = hashlib.new(name, (salt + plaintextpassword).encode()).digest()
    while n:
        n -= 1
        d = hashlib.new(name, d).digest()
    return hashlib.new(name, d).hexdigest()


def getsalt(randombits=64):
    if randombits < 16:
        raise ValueError("randombits < 16")
    return "%016x" % sr().getrandbits(randombits)


def is_test():
    """Check whether we are in the midst of a nosetest."""
    if 'WEBPY_ENV' in os.environ:
        return os.environ['WEBPY_ENV'] == 'test'


CONFIG = ConfigParser.ConfigParser()

CURDIR = os.path.dirname(os.path.realpath(__file__))
CONFIGPATH = os.path.abspath(os.path.join(CURDIR, os.pardir, os.pardir, "main.conf"))

CONFIG.read(CONFIGPATH)

dbconfig = {}
for i in ('dbn', 'db', 'host', 'user', 'password'):
    dbconfig[i] = CONFIG.get('database', i)
imagedbconfig = {}
for i in ('dbn', 'db', 'host', 'user', 'password'):
    imagedbconfig[i] = CONFIG.get('imagedatabase', i)

debug = CONFIG.getboolean('main', 'debug')
debug_sql = CONFIG.getboolean('main', 'debug_sql')
dbprinting = CONFIG.getboolean('main', 'dbprinting')
