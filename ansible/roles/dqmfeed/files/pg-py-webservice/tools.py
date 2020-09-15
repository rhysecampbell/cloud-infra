'''
Created on 1 Feb 2012

@author: JPC
'''
import web
import csv
from app.common.common import dbconfig

PGDB = web.database(**dbconfig)

def fresh_datex2db():
    transaction = PGDB.transaction()
    PGDB.query("delete from exportws.xmltags;")
    PGDB.query("delete from exportws.lanes;")
    PGDB.query("delete from exportws.groups;")
    PGDB.query("delete from exportws.sensorindex;")
    PGDB.query("delete from exportws.sensors;")
    PGDB.query("delete from exportws.stations;")
    
    csvReader = csv.DictReader(open('c:\\documents and settings\\jpc\\workspace\\py-pg-webservice\\database\\xmltags.txt', 'rb'))
    xmltags = []
    for row in csvReader:
        xmltags.append(row)
    
    PGDB.multiple_insert('exportws.xmltags', xmltags)
    csvReader = csv.DictReader(open('c:\\documents and settings\\jpc\\workspace\\py-pg-webservice\\database\\sensorindex.txt', 'rb'))
    sensorindex = []
    for row in csvReader:
        sensorindex.append(row)
    
    PGDB.multiple_insert('exportws.sensorindex', sensorindex)
    transaction.commit()