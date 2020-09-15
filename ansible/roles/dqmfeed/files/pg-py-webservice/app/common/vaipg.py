#!/usr/bin/env python

"""
Provide the Island class for working with a Vaisala Island system's
Postgres database.

Requires the exportws schema.
"""

import web
import logging

from common import InjectingFilter, hashpassword, dbconfig, getsalt
from common import debug, debug_sql, dbprinting, coord_intstr
from datetime import timedelta
from datex2 import DataXML as Datex2XML, MstXML
from vaisalaobs import VaisalaObsXML
from qttntcipobs import QttNtcipObsXML

logfilter = InjectingFilter()
log = logging.getLogger('app.common.vaipg')
log.addFilter(logfilter)

web.config.debug = debug
web.config.debug_sql = debug_sql

db = web.database(**dbconfig)
db.printing = dbprinting


def station_row(pg_id=None):
    return db.select('icecast.station',
                     where="station_id=$pg_id",
                     vars={'pg_id': pg_id, })[0]


class Data:
    def __init__(self, rows, stations):
        self.rows = rows
        self.stations = stations

    def datex2(self):
        return Datex2XML(self.rows).xml()

    def vaisalaobs(self):
        return VaisalaObsXML(self.rows).xml()

    def qttntcipobs(self):
        return QttNtcipObsXML(self.rows).xml()

    def vai_crosstab(self):
        """
        Run through postgres data and return list more easily traversible
        by date

        result[vmdb_id][datetime, {sensorid: value}]
        sensortable[vmdb_id][id]=(symbol, number)
        """
        data = {}
        sensortable = {}
        for row in self.rows:
            if row.data_symbol in ('WDM', 'WD', 'RH', 'VI', ):
                value = int(row.data_value)
            else:
                value = row.data_value
            date = row.data_time
            sensor_id = row.sensor_id
            if not sensor_id in sensortable:
                sensortable[sensor_id] = (row.data_symbol, row.data_number)
            if row.vmdb_id in data:
                if date in data[row.vmdb_id]:
                    data[row.vmdb_id][date][sensor_id] = value
                else:
                    data[row.vmdb_id][date] = {sensor_id: value, }
            else:
                data[row.vmdb_id] = {date: {sensor_id: value, }, }
        for vmdb_id, dates in data.iteritems():
            data[vmdb_id] = [(k, dates[k]) for k in sorted(dates.keys(),
                                                           reverse=True)]
        return data, sensortable


class Station:
    def __init__(self, pg_id=None, vmdb_id=None):
        if pg_id:
            pass
        elif vmdb_id:
            pg_id = station_id(vmdb_id)
        else:
            raise ValueError('Need a station identifier.')
        self.row = station_row(pg_id)
        for coord in "latitude", "longitude":
            self.row[coord] = coord_intstr(self.row[coord])

    def lastupdate(self, datatype='obs'):
        #TODO: Perhaps use iceupdate_region_request.last_request instead?
        table = {'obs': 'icecast.value_control',
                 'jpg': 'icecast.station_image'}
        if datatype in table.iterkeys():
            log.debug('checking modified')
            timestamp = db.query("""SELECT MAX(entry_datetime)
                                      AS highest
                                    FROM %s
                                    WHERE station_id=$station""" \
                                 % table[datatype],
                                 vars={'station': self.row['station_id'], }
                                 )[0].highest
            return timestamp

    def data(self, earliesttime=None, latesttime=None, lastget=None,
             raise_exception=True):
        """
        Return data for an individual station after earliesttime &
        before latesttime.
        """
        ## TODO: Better latesttime & earliesttime checking. Limits?
        log.debug("starting station request...")
        if raise_exception:
            web.modified(self.lastupdate('obs'))
        sql = []
        sql.append("""select vc.mes_datetime as data_time,
                             s.sensor_id as sensor_id,
                             v.value_num/s.scaling as data_value,
                             s.symbol as data_symbol,
                             s.data_number as data_number,
                             st.vmdb_id as vmdb_id,
                             x.xmltagname as xmltagname,
                             x.xsitype as xsitype,
                             di.datex_id as datex_id,
                             st.station_name as station_name
                      from icecast.value v, icecast.value_control vc,
                           icecast.sensor s, icecast.application_symbol app_s,
                           icecast.station st, exportws.xmltags x,
                           exportws.sensorindex di
                      where v.vc_id = vc.vc_id
                      and v.value_status>= 0
                      and v.vc_id in""")
        variables = {'stationid': self.row['station_id'], }
        if earliesttime or latesttime:
            sql.append("""( select vc_id
                            from icecast.value_control
                            where station_id = $stationid""")
            if earliesttime:
                log.debug("extracting from %s" % earliesttime)
                sql.append("and mes_datetime >= $earliesttime")
                variables['earliesttime'] = earliesttime
            if latesttime:
                log.debug("extracting since %s" % latesttime)
                sql.append("and mes_datetime <= $latesttime")
                variables['latesttime'] = latesttime
            sql.append(")")
        elif lastget:
            log.debug("extracting data since %s" % lastget)
            # We can't use > over >= in the sql as entry_datetime is stored
            # to sub-second accuracy in postgres. (mes_datetime isn't!!)
            # We'll just add a second to lastget instead.
            sql.append("""( select vc_id
                            from icecast.value_control
                            where station_id = $stationid
                            and entry_datetime >= $nextget
                           )""")
            variables['nextget'] = lastget + timedelta(seconds=1)
        else:
            sql.append("""( select max(vc_id)
                            from icecast.value_control
                            where station_id = $stationid
                           )""")
        sql.append("""and v.sensor_id = s.sensor_id
                      and s.symbol = app_s.symbol
                      and s.symbol = x.data_symbol
                      and s.symbol = di.data_symbol
                      and s.data_number = di.data_number
                      and app_s.application_key = 'ExportObservationXML'
                      and vc.station_id = st.station_id
                      order by vc.mes_datetime; """)
        result = db.query(' '.join(sql), vars=variables)
        if not result and raise_exception:
            # FIXME: Should this be here?
            web.header('Content-Type', 'text/html; charset=utf-8')
            raise web.HTTPError("404 not found", {}, "No data available.")
        return Data(result, {self.row['vmdb_id']: self,})

    def mst(self, lastget=None):
        return MstXML(station_row=self.row)

    def jpg(self, cam=1, latesttime=None):
        """Return Image"""
        web.modified(self.lastupdate('jpg'))
        sql = []
        sql.append("""SELECT * FROM icecast.station_image
                      WHERE station_id = $stationid
                      AND camera_no = $camerano
                      AND image_datetime = (SELECT MAX(image_datetime)
                                              FROM icecast.station_image
                                              WHERE station_id = $stationid
                                              AND camera_no = $camerano""")
        variables = {'stationid': self.row['station_id'], 'camerano': cam, }
        if latesttime:
            sql.append("AND image_datetime <= $latesttime")
            variables['latesttime'] = latesttime
        sql.append(")")
        try:
            return db.query(' '.join(sql), variables)[0].image_content
        except IndexError:
            web.header("Content-Type", "text/html")
            raise web.HTTPError("404 not found", {},
                                "No camera image available.")

    def jpglist(self, cam=None):
        return db.select('icecast.station_image',
                         what="camera_no, image_datetime",
                         where="station_id = $stationid",
                         order="image_datetime desc",
                         vars={'stationid': self.row['station_id']})


def region_row(pg_id):
    return db.select('icecast.region',
                     where="region_id=$region_id",
                     vars={'region_id': pg_id, })[0]


class Region:
    def __init__(self, vmdb_id=None, pg_id=None):
        if pg_id:
            pass
        elif vmdb_id:
            pg_id = region_id(vmdb_id)
        else:
            raise ValueError('Need a region identifier.')
        self.row = region_row(pg_id)

    def stations(self):
        stations = {}
        result = db.query("""select *
                             from icecast.region_station as rs
                             join icecast.station as s
                               on rs.station_id = s.station_id
                             where rs.region_id = $region_id
                               and s.vmdb_id<>0""",
                          vars={'region_id': self.row['region_id'], }, )
        for row in result:
            stations[row.vmdb_id] = row
        return stations

    def data(self, earliesttime=None, latesttime=None, lastget=None):
        """Return result for all stations within region_id."""
        #TODO: So many requests... we can do this better.
        #TODO: If-Modified-Since check for region
        log.debug("starting region-wide request")
        stations = {}
        result = []
        for vmdb_id in self.stations():
            stations[vmdb_id] = Station(vmdb_id=vmdb_id)
            data = stations[vmdb_id].data(earliesttime, latesttime, lastget,
                                          raise_exception=False)
            for row in data.rows:
                result.append(row)
        return Data(result, stations)

    def mst(self, lastget=None):
        return MstXML(region_row=self.row, station_row=self.stations())


secure_hash = 'sha256'
iterations = 1000
saltbits = 64


def check_password(user, plaintextpassword):
    """
    Authenticate user's password.

    Raises 401 HTTPError on failure.
    """
    log.debug("user=%s" % user)
    result = db.select('exportws.pwdb', what="pwdb.salt",
                       where="pwdb.username=$user",
                       vars={'user': user, })
    try:
        salt = result[0].salt
        log.debug("Got salt.")
        passwordhash = hashpassword(secure_hash, salt,
                                    plaintextpassword, iterations)
        db.select('exportws.pwdb', what='user',
                  where="""pwdb.username = $user
                           and pwdb.password = $hash""",
                  vars={'user': user, 'hash': passwordhash})[0]
    except IndexError:
        log.debug("user=%s authn=False" % user)
        web.header("WWW-Authenticate", 'Basic realm="Vaisala Data Export"')
        web.header('Content-Type', 'text/html; charset=utf-8')
        raise web.HTTPError("401 unauthorized", {}, \
                            "Please use a valid username & password.")
    log.debug("user=%s authn=True" % user)
    return True


def check_admin(username):
    """
    Return True if user is an admin or False otherwise.

    Does not raise an exception. - Use check_admin_password for that.
    """
    return check_region_role(username, "admin")


def check_admin_password(username, password):
    """
    Authenticate's user's password and checks they are an admin.

    Raises an exception on failure.
    """

    if check_password(username, password) and check_admin(username):
        log.debug("username=%s authz=admin" % (username))
        return True
    else:
        log.info("username=%s admin=False" % (username))
        web.header('Content-Type', 'text/html; charset=utf-8')
        web.header("WWW-Authenticate",
                   'Basic realm="Vaisala Data Export Admin"')
        raise web.HTTPError("401 unauthorized", {},
                            "You are not authorized to use this resource.")


def station_id(vmdb_id):
    try:
        return db.select('icecast.station', where="vmdb_id=$vmdb_id",
                         what="station_id",
                         vars={'vmdb_id': vmdb_id, })[0].station_id
    except IndexError:
        web.header("Content-Type", "text/html")
        raise web.HTTPError("404 not found", {},
                            "Station not found.")


def region_id(vmdb_id):
    try:
        return db.select('icecast.region', where="vmdb_id=$vmdb_id",
                         what="region_id",
                         vars={'vmdb_id': vmdb_id, })[0].region_id
    except IndexError:
        web.header("Content-Type", "text/html")
        raise web.HTTPError("404 not found", {},
                            "Region not found.")


def session(username, password, region=None, station=None, role=None,
            admin=False,):
    if admin:
        check_admin_password(username, password)
    else:
        check_password(username, password)
    return authz(username, role, region, station)


def authz(username, role=None, region=None, station=None):
    """
    Authorize username against region as well as optional role & station.

    Returns Station or Region object to be queried for data.
    """
    if station:
        try:
            station = int(station)
        except TypeError:
            log.info("station=%s message='invalid station'" % (station))
            raise web.HTTPError("404 not found", {}, "'%s' is not a valid station." \
                                                     % station)
    if check_admin(username):
        if station:
            log.info("user=%s admin=True authz=True finalauthz=True role=%s station=%s" \
                     % (username, role, station))
            return Station(vmdb_id=station)
        elif region:
            log.info("user=%s admin=True authz=True finalauthz=True role=%s region=%s" \
                     % (username, role, region))
            return Region(vmdb_id=region)
        else:
            log.info("user=%s admin=True authz=True finalauthz=True role=%s message='Admin is being a fool'" \
                     % (username, role))
            raise web.HTTPError("404 not found", {}, "Fool of a took!")
    possible_regions = []
    if region:
        log.debug("possible_regions=%s" % region)
        possible_regions.append(region)
    else:
        regions = list_users_roles(username)
        for row in regions:
            if row.region not in possible_regions:
                possible_regions.append(row.region)
        log.debug("possible_regions=%s" % possible_regions)
    for regiontotest in possible_regions:
        testregion = Region(vmdb_id=regiontotest)
        if check_region_role(username, testregion.row['vmdb_id'], role, ):
            if station:
                log.debug("region=%s testregion_stations=%s" % (regiontotest, testregion.stations().keys()))
                if station in testregion.stations():
                    log.info("username=%s authz=True finalauthz=True role=%s region=%s station=%s" \
                             % (username, role, regiontotest, str(station)))
                    return Station(vmdb_id=station)
                else:
                    log.debug("username=%s authz=False finalauthz=False role=%s region=%s station=%s" \
                              % (username, role, regiontotest, str(station)))
            else:
                log.info("username=%s authz=True finalauthz=True role=%s region=%s" \
                         % (username, role, regiontotest))
                return testregion
        else:
            log.debug("username=%s authz=False finalauthz=False role=%s region=%s" \
                      % (username, role, regiontotest))
    else:
        # no regions in the list, we've failed to authorize.
        log.info("username=%s authz=False finalauthz=True region=%s station=%s" \
                 % (username, str(region), str(station)))
        web.header('Content-Type', 'text/html; charset=utf-8')
        raise web.HTTPError("401 unauthorized", {}, "You are not authorized.")


def check_region_role(user, region, role=None):
    """Authorize user for (role from) region."""
    if role:
        result = db.select('exportws.permissions',
                           where="""permissions.username=$user
                                    and permissions.region='$region'
                                    and permissions.role=$role""",
                           vars={'user': user, 'region': region, 'role': role})
    else:
        result = db.select('exportws.permissions',
                           where="""permissions.username=$user
                                    and permissions.region=$region""",
                           vars={'user': user, 'region': region, })
    return len(list(result)) == 1


def list_users():
    """Return a list of all users."""
    return db.select('exportws.pwdb', )


def list_users_roles(user=None):
    """
    Return a list of all user's roles.

    If user is specified, only their roles.
    """
    if user:
        return db.query("""select * from exportws.pwdb
                           left join exportws.permissions
                             on pwdb.username=permissions.username
                           where pwdb.username = $user""",
                        vars={'user': user, })
    else:
        return db.query("""select * from pwdb
                           left join permissions
                             on exportws.pwdb.username=exportws.permissions.username""",)


def add_permission(user, region, role, ):
    """Allow user access to role from region."""
    db.insert('exportws.permissions',
              username=user, region=region, role=role)


def delete_permission(user, region, role):
    """Delete any entries allowing user access to role from region."""
    db.delete('exportws.permissions',
              where="""username = $user
                       and region = $region
                       and role = $role""",
              vars={'user': user, 'region': region, 'role': role})


def check_station_in_region(regionid, stationid, ):
    """Return joined rs, r, s row if station in region, False otherwise."""
    try:
        return db.query("""select *
                           from icecast.region_station as rs
                           join icecast.region as r
                             on r.region_id = rs.region_id
                           join icecast.station as s
                             on rs.station_id = s.station_id
                           where s.vmdb_id = $stationid
                             and r.vmdb_id = $regionid""",
                        vars={'stationid': stationid,
                              'regionid': regionid},
                        )[0]
    except IndexError:
        return False


def update_pwdb(user, plaintextpassword):
    """Change user password."""
    salt = getsalt(saltbits)
    passwordhash = hashpassword(secure_hash, salt,
                                plaintextpassword, iterations)
    existing = db.select('exportws.pwdb',
                         where="username=$user",
                         vars={'user': user, })
    if len(existing) == 1:
        db.update('exportws.pwdb',
                         where="username = $user",
                         vars={'user': user, },
                         password=passwordhash,
                         salt=salt)
    else:
        db.insert('exportws.pwdb',
                  username=user, salt=salt, password=passwordhash)
