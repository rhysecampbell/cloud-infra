#!/usr/bin/env python
#FORMAT PYTHON

"""provides an html interface into password.db"""

import web
import logging
import os

from web import form
from app.common.common import is_test, InjectingFilter, dbconfig, get_httpauth
from app.common.common import dbprinting
from app.common.vaipg import update_pwdb, check_admin_password, list_users
from app.common.vaipg import list_users_roles, add_permission
from app.common.vaipg import delete_permission
from app.common.datex2 import update_mst_date

CURDIR = os.path.dirname(__file__)
RENDER = web.template.render(os.path.join(CURDIR, 'templates'))

db = web.database(**dbconfig)
db.printing = dbprinting


URLS = (
  '', 'Index',
  '/', 'Index',
  '/users', 'AdminUsers',
  '/roles', 'AdminRoles',
  '/mst', 'AdminMst',
  '/mst/stations', 'AdminMstStations',
  '/mst/lanes', 'AdminMstLanes',
  '/qttids', 'QttIds'
)

APP = web.application(URLS, globals(), autoreload=False)

logfilter = InjectingFilter()
log = logging.getLogger('app.admin')
log.addFilter(logfilter)

USERFORM = form.Form(
    form.Dropdown('operation', ['update', 'delete']),
    form.Textbox('username'),
    form.Textbox('password'),
)

ROLEFORM = form.Form(
     form.Textbox('username'),
     form.Textbox('region'),
     form.Radio('role', ['xml', 'jpg', 'datex2', 'qtt']),
     form.Radio('action', ['add', 'delete']),
)


class Index:
    """Provide links to admin functions."""
    def GET(self):
        check_admin_password(*get_httpauth())
        web.header('Content-Type', 'text/html; charset=utf-8', unique=True)
        return '<body>Head to <a href="/admin/users">user</a> ' \
               '<a href="/admin/roles">roles</a> or ' \
               '<a href="/admin/mst">mst</a> or ' \
               '<a href="/admin/qttids">qttids</a> admin.</body>'


class AdminUsers:
    """Allow updating & addition of users."""
    def GET(self):
        check_admin_password(*get_httpauth())
        userlist = list_users()
        userform = USERFORM()
        web.header('Content-Type', 'text/html; charset=utf-8')
        return RENDER.useradmin(userlist, userform)

    def POST(self):
        check_admin_password(*get_httpauth())
        userform = USERFORM()
        if not userform.validates():
            return RENDER.formtest(userform)
        if userform.d.operation == u'update':
            if userform.d.username and userform.d.password:
                update_pwdb(userform.d.username, userform.d.password)
            else:
                log.info("username & password missing")
                web.header('Content-Type', 'text/html; charset=utf-8')
                raise web.HTTPError("400 bad request", {},
                                    "Please supply a username & password.")
        elif userform.d.operation == u'delete':
            if userform.d.username:
                #TODO: Should we automatically delete all roles?
                db.delete('exportws.pwdb', where="pwdb.username=$user",
                          vars={'user': userform.d.username, }, )
            else:
                log.info("username missing")
                web.header('Content-Type', 'text/html; charset=utf-8')
                raise web.HTTPError("400 bad request", {},
                                    "Please supply a username.")
        log.info("operation=%s targetusername=%s" % \
                     (userform.d.operation, userform.d.username, ))
        raise web.seeother('/users')


class AdminRoles:
    """Interface for managing user's access."""
    def GET(self):
        i = web.input(username=None)
        check_admin_password(*get_httpauth())
        rolelist = list_users_roles(i.username)
        roleform = ROLEFORM()
        web.header('Content-Type', 'text/html; charset=utf-8')
        return RENDER.roleadmin(rolelist, roleform)

    def POST(self):
        check_admin_password(*get_httpauth())
        roleform = ROLEFORM()
        if not roleform.validates():
            return RENDER.formtest(ROLEFORM)
        log.info("operation=%s targetusername=%s" % \
                 (roleform.d.action, roleform.d.username, ))
        if roleform.d.action == "add":
            add_permission(roleform.d.username,
                           roleform.d.region,
                           roleform.d.role)
        elif roleform.d.action == "delete":
            delete_permission(roleform.d.username,
                              roleform.d.region,
                              roleform.d.role)
        raise web.seeother('/roles')


class AdminMst:
    """Provides links to Datex2 Measurement Site table configuration."""
    def GET(self):
        check_admin_password(*get_httpauth())
        web.header('Content-Type', 'text/html; charset=utf-8', unique=True)
        return '<h1>MST Configuration</h1><p>Please head to ' \
               '<a href="/admin/mst/lanes">lanes</a> or ' \
               '<a href="/admin/mst/stations">stations</a> configuration.'

DATEX2_DIRECTIONS = ("allDirections", "bothWays", "clockwise", "anticlockwise",
                     "innerRing", "outerRing", "northBound", "northEastBound",
                     "eastBound", "southEastBound", "southBound",
                     "southWestBound", "westBound", "northWestBound",
                     "inboundTowardsTown", "outboundFromTown", "unknown",
                     "opposite", "other",
                     )

DATEX2_LANE_NAMES = ("allLanesCompleteCarriageway", "busLane", "busStop",
                     "carPoolLane", "centralReservation", "crawlerLane",
                     "emergencyLane", "escapeLane", "expressLane",
                     "hardShoulder", "heavyVehicleLane", "lane1", "lane2",
                     "lane3", "lane4", "lane5", "lane6", "lane7", "lane8",
                     "lane9", "layBy", "leftHandTurningLane", "leftLane",
                     "localTrafficLane", "middleLane", "opposingLanes",
                     "overtakingLane", "rightHandTurningLane", "rightLane",
                     "rushHourLane", "setDownArea", "slowVehicleLane",
                     "throughTrafficLane", "tidalFlowLane", "turningLane",
                     "verge",
                     )

# XXX: Needs to have both side & direction...?
MST_ADMIN_STATION_FORM = form.Form(
     form.Hidden('station'),
     form.Dropdown('measurementside', [DATEX2_DIRECTIONS]),
     form.Button('Submit'),
     )


class AdminMstStations:
    """Allows configuration of station specific Datex2 MST parameters."""
    def GET(self):
        check_admin_password(*get_httpauth())
        i = web.input(station=None)
        vmdb_id = i.station
        if vmdb_id:
            stations = db.query("""SELECT * FROM exportws.stations as st
                                   JOIN icecast.station as s
                                     ON s.vmdb_id=st.vmdb_id
                                   WHERE s.vmdb_id=$vmdb_id
                                   ORDER BY s.vmdb_id ASC""",
                                vars={'vmdb_id': vmdb_id, })
        else:
            stations = db.query("""SELECT * FROM exportws.stations as st
                                   JOIN icecast.station as s
                                     ON s.vmdb_id=st.vmdb_id
                                   ORDER BY s.vmdb_id ASC""")
        return RENDER.adminmststations(stations, )

    def POST(self):
        check_admin_password(*get_httpauth())
        stationform = MST_ADMIN_STATION_FORM()
        if not stationform.validates():
            return '<h1>Failure</h1>'
        log.info("station=%s" % (stationform.d.station, ))
        db.update("exportws.stations",
                  measurementside=stationform.d.measurementside,
                  where="vmdb_id=$vmdb_id",
                  vars={'vmdb_id': stationform.d.station, })
        update_mst_date(stationform.d.station)
        raise web.seeother('/mst/stations')

MSTADMINLANEFORM = form.Form(
     form.Hidden('station'),
     form.Hidden('number'),
     form.Checkbox('reverse'),
     form.Dropdown('lane_name', [DATEX2_LANE_NAMES]),
     form.Dropdown('direction', [DATEX2_DIRECTIONS]),
     form.Button('Submit'),
     )

MSTADMINDIRECTIONFORM = form.Form(
     form.Hidden('station'),
     form.Hidden('number'),
     form.Checkbox('reverse'),
     form.Dropdown('direction', [DATEX2_DIRECTIONS]),
     form.Button('Submit'),
     )


class AdminMstLanes:
    """Allows configuration of station+lane specific Datex2 configuration."""
    def GET(self):
        check_admin_password(*get_httpauth())
        i = web.input(station=None)
        vmdb_id = i.station
        if vmdb_id:
            lanes = db.query("""SELECT *
                                FROM exportws.lanes as l
                                JOIN exportws.groups as g
                                  ON g.vmdb_id = l.vmdb_id
                                  AND g.data_number = l.data_number
                                JOIN icecast.station as s
                                  ON s.vmdb_id = g.vmdb_id
                                WHERE g.vmdb_id = $vmdb_id
                                ORDER BY g.vmdb_id, g.data_number ASC""",
                             vars={'vmdb_id': vmdb_id, })
        else:
            lanes = db.query("""SELECT *
                                FROM exportws.lanes as l
                                JOIN exportws.groups as g
                                  ON g.vmdb_id = l.vmdb_id
                                  AND g.data_number = l.data_number
                                JOIN icecast.station as s
                                  ON s.vmdb_id = g.vmdb_id
                                ORDER BY g.vmdb_id, g.data_number ASC""",)
        return RENDER.adminmstlanes(lanes, )

    def POST(self):
        check_admin_password(*get_httpauth())
        laneform = MSTADMINLANEFORM()
        if not laneform.validates():
            return '<h1>Failure</h1>'
        log.info("station=%s laneupdate" % (laneform.d.station, ))
        db.query("""UPDATE exportws.lanes
                    SET reverse=$reverse,
                        lane_direction=$lane_direction
                    WHERE vmdb_id=$vmdb_id
                      AND data_number=$data_number""",
                 vars={'vmdb_id': laneform.d.station,
                       'reverse': laneform.d.reverse,
                       'lane_direction': laneform.d.direction,
                       'data_number': laneform.d.number, })
        db.query("""UPDATE exportws.groups
                    SET lane_name=$lane_name
                    WHERE vmdb_id=$vmdb_id
                      AND data_number=$data_number""",
                 vars={'vmdb_id': laneform.d.station,
                       'lane_name': laneform.d.lane_name,
                       'data_number': laneform.d.number, })
        update_mst_date(laneform.d.station)
        raise web.seeother('/mst/lanes?station=' + str(laneform.d.station))

QTTFORM = form.Form(
    form.Dropdown('operation', ['add', 'delete']),
    form.Textbox('vmdb_id'),
    form.Textbox('qtt_id'),
)

class QttIds:
    """Allow updating & addition of qttids."""
    def GET(self):
        check_admin_password(*get_httpauth())
        qttlist = db.select('exportws.qttids', )
        qttform = QTTFORM()
        web.header('Content-Type', 'text/html; charset=utf-8')
        return RENDER.qttadmin(qttlist, qttform)

    def POST(self):
        check_admin_password(*get_httpauth())
        qttform = QTTFORM()
        if not qttform.validates():
            return RENDER.formtest(qttform)
        if qttform.d.operation == u'add':
            if qttform.d.vmdb_id and qttform.d.qtt_id:
                db.insert('exportws.qttids',
                          vmdb_id=qttform.d.vmdb_id,
                          qtt_id=qttform.d.qtt_id)
            else:
                log.info("vmdb_id or qtt_id missing")
                web.header('Content-Type', 'text/html; charset=utf-8')
                raise web.HTTPError("400 bad request", {},
                                    "Please supply a vmdb_id & qtt_id.")
        elif qttform.d.operation == u'delete':
            if qttform.d.vmdb_id or qttform.d.qtt_id:
                if qttform.d.vmdb_id:
                    db.delete('exportws.qttids', where="vmdb_id=$vmdb_id",
                              vars={'vmdb_id': qttform.d.vmdb_id})
                if qttform.d.qtt_id:
                    db.delete('exportws.qttids', where="qtt_id=$qtt_id",
                              vars={'qtt_id': qttform.d.qtt_id})
            else:
                log.info("vmdb_id or qtt_id missing")
                web.header('Content-Type', 'text/html; charset=utf-8')
                raise web.HTTPError("400 bad request", {},
                                    "Please supply a qtt_id or vmdb_id.")
        log.info("operation=%s vmdb_id=%s qtt_id=%s" % \
                     (qttform.d.operation, qttform.d.vmdb_id, qttform.d.qtt_id ))
        raise web.seeother('/qttids')



application = APP.wsgifunc()

if (not is_test()) and __name__ == "__main__":
    # Ok lets run the builtin webserver..
    logging.basicConfig(level=logging.DEBUG,
                    format='%(asctime)s %(process)d %(thread)d ' \
                           '%(levelname)s: %(ip)s %(method)s %(path)s ' \
                           '%(name)s %(message)s',
                    datefmt='%Y%m%dT%H%M%S')
    web.config.debug_sql = True
    web.config.debug = True
    APP.run()
