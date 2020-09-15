'''
Created on 20 Jan 2012

@author: JPC
'''
from paste.fixture import TestApp
from nose.tools import *
from lxml import etree
import web

from server import APP
from tools import fresh_datex2db
from app.common.common import coord_intstr, dbconfig

users = {200: {'admin': {'username':'adminuser', 'password':'adminpass'},
              'datex2': {'username':'datexuser', 'password':'datexpass'},
              'xml': {'username':'xmluser', 'password':'xmlpass'},
              'jpg': {'username':'jpguser', 'password':'jpgpass'},
              },
        401: {'blank': {'username':'', 'password':''},
              'none': {},
              'admin': {'username':'adminuser', 'password':'wrongpassword1'},
              'datex2': {'username':'datexuser', 'password':'wrongpassword2'},
              'xml': {'username':'xmluser', 'password':'wrongpassword3'},
              'jpg': {'username':'jpguser', 'password':'wrongpassword4'},
             },
       }

urls = (('/', ('admin', 'datex2', 'xml', 'jpg', ), 'text/html', ),
        ('/admin', ('admin', ), 'text/html', ),
        ('/admin/users', ('admin', ), 'text/html', ),
        ('/admin/roles', ('admin', ), 'text/html', ),
        ('/admin/mst', ('admin', ), 'text/html', ),
        ('/admin/mst/stations', ('admin', ), 'text/html', ),
        ('/admin/mst/lanes', ('admin', ), 'text/html', ),
        ('/export', ('admin', 'xml', ), 'text/xml', ),
        ('/export/vaisalaobs.xml', ('admin', 'xml', ), 'text/xml', ),
        ('/jpglist.html', ('admin', 'jpg', ), 'text/html', ),
        ('/export/image.jpg', ('admin', 'jpg', ), 'image/jpeg', ),
        ('/datex2/content.xml', ('admin', 'datex2', ), 'text/xml', ),
        ('/datex2/mst.xml', ('admin', 'datex2', ), 'text/xml', ),
        )

urlsreqstation = ['/jpglist.html', '/export/image.jpg',
                  #'/export', '/export/vaisalaobs.xml',
                  #'/datex2/content.xml', '/datex2/mst.xml',
                  ]

testApp = TestApp(APP.wsgifunc())

# Don't run on production... could do witha better test but 'meh'
if dbconfig['host'] in ("localhost", "192.168.32.40"):
    raise

PGDB = web.database(**dbconfig)

@nottest
def setup_passworddb():
    transaction = PGDB.transaction()
    PGDB.delete('exportws.permissions', where="True")
    PGDB.delete('exportws.pwdb', where="True")
    values = [{'username': 'adminuser', 'salt': '193d86e05c851bba', 'password': '1af5569ecb7d56d13f873c4507ca49f583a61b2758fdcf776b6c099385d614b2'},
              {'username': 'datexuser', 'salt': 'f7a9531e38f80fd2', 'password': 'd96d1b998de410fa1bbddc60f0382ac041b7660db932ff00bcbee9d5efd3d030'},
              {'username': 'xmluser', 'salt': '39d866efdbcf741c', 'password': '5643e3fd8c8c700829507966f7f6b45b7dbff74f91048624de2766683e409047'},
              {'username': 'jpguser', 'salt': 'c299423f557fd784', 'password': 'dcf8993367eee5a0307892cf9010d2a9ffa16acff891a32776e82bfadbd7d538'},
              ]
    PGDB.multiple_insert('exportws.pwdb', values=values)
    values = [{'username': 'adminuser', 'region': 'admin', 'role': 'admin'},
              {'username': 'xmluser', 'region': '317', 'role': 'xml'},
              {'username': 'datexuser', 'region': '317', 'role': 'datex2'},
              {'username': 'jpguser', 'region': '317', 'role': 'jpg'},
              ]
    PGDB.multiple_insert('exportws.permissions', values=values)
    transaction.commit()


def check_authnz(url, response, params, contenttype):
    print url, response, params, contenttype
    response = testApp.get(url, status=response, params=params)
    print response.header_dict
    assert contenttype in response.header_dict['content-type']


@nottest
def run_coordtrans(pgdb, real):
    test = coord_intstr(pgdb)
    print pgdb, real, test
    assert test == real


def test_coordtrans():
    for coordinate in ((-1673610, -1.67361),
                       (55125000, 55.125),
                       (58060, 0.058060)):      # M25 Croydon
        yield run_coordtrans, coordinate[0], coordinate[1]


@with_setup(setup_passworddb, None)
def test_authnz():
    for url, permission, contenttype in urls:
        for response, roles in users.iteritems():
            for role, params in roles.iteritems():
                if role == 'admin':
                    pass
                elif role in permission:
                    if response == 401:
                        yield check_authnz, url, 401, params, 'text/html'
                    elif url in urlsreqstation:
                        yield check_authnz, url, 403, params, 'text/html'
                    else:
                        yield check_authnz, url, response, params, contenttype
                else:
                    yield check_authnz, url, 401, params, 'text/html'

schema_file = open('static/DATEXIISchema_2_0RC2_2_0_EssExtension_2_1.xsd')
schema_doc = etree.parse(schema_file)
schema_file.close()
schema = etree.XMLSchema(schema_doc)
datex2parser = etree.XMLParser(schema=schema)

@nottest
def verify_schema(data):
    etree.fromstring(data, datex2parser)

@nottest
def verify_payload_schema(xml):
    replaces = ("""<soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/" xmlns:env="http://www.w3.org/2001/XMLSchema-instance" xmlns:xdt="http://www.w3.org/2004/07/xpath-datatypes" xmlns:xsd="http://www.w3.org/2001/XMLSchema" env:schemaLocation="http://schemas.xmlsoap.org/soap/envelope/ http://schemas.xmlsoap.org/soap/envelope/">""",
                """<soapenv:Body>""",
                """</soapenv:Body>""",
                """</soapenv:Envelope>""",)
    for replace in replaces:
        xml = xml.replace(replace, "")
    verify_schema(xml)

@nottest
def check_schema_for_station(vmdb_id):
    params = users[200]['admin']
    params['station'] = vmdb_id
    print params
    response = testApp.get("/datex2/content.xml", params=params)
    verify_payload_schema(response.body)
    response = testApp.get("/datex2/mst.xml", params=params)
    verify_schema(response.body)

sql_check_data = """select mes_datetime
                    from icecast.value v, icecast.value_control vc,
                         icecast.sensor s, icecast.application_symbol app_s
                    where v.vc_id = vc.vc_id
                    and v.value_status>= 0
                    and v.vc_id in( select max(vc_id)
                                    from icecast.value_control
                                    where station_id = $station_id
                                   )
                    and v.sensor_id = s.sensor_id
                    and s.symbol = app_s.symbol
                    and app_s.application_key = 'ExportObservationXML'
                    order by vc.mes_datetime;"""


@with_setup(fresh_datex2db, fresh_datex2db)
def test_all_stations_datex2():
    stations = PGDB.select('icecast.station', order='vmdb_id ASC', )
    for station in stations:
        if PGDB.query(sql_check_data, vars={"station_id": station.station_id}):
            yield check_schema_for_station, station.vmdb_id

#TODO: Test all the things!