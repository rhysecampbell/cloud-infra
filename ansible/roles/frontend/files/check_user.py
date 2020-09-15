#!/usr/bin/python
import sys
import psycopg2
import ConfigParser

config = ConfigParser.RawConfigParser()
config.read('/etc/vaisala-config/settserver.cfg')
dbstring = "host=%s dbname=%s user=%s password=%s" % (config.get('authdb', 'host'),
                                                      config.get('authdb', 'database'),
                                                      config.get('authdb', 'user'),
                                                      config.get('authdb', 'password'))

user = sys.stdin.readline().strip()
pw = sys.stdin.readline().strip()

try:
    conn = psycopg2.connect(dbstring)
    cur = conn.cursor()
    cur.execute("SELECT * FROM users WHERE username = %s AND password = md5(%s)", (user, pw))
    if cur.fetchone() == None:
        sys.exit(1)
except Exception, e:
    sys.exit(2)
sys.exit(0)

