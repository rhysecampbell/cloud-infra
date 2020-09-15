#!/usr/bin/env python

'''
Created on 4 May 2012

@author: JPC
'''
import web

from app.common.common import dbconfig
from sys import argv
from datetime import datetime


PGDB = web.database(**dbconfig)
PGDB.printing = False

def ingest_xml(string):
    return PGDB.query('''select * from icecast.xml_insert($string)''',
                      vars={'string': string, })[0]

def ingest_file(file):
    try:
        FILE = open(file, "r")
    except IOError, e:
        print e
        return
    contents = FILE.read()
    FILE.close()
    return ingest_xml(contents)

for file in argv[1:]:
    print datetime.now(), "processing", file
    print ingest_file(file), "returned"
    print datetime.now(), "processed", file
