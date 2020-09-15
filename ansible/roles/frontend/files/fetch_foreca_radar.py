#!/usr/bin/env python

import sys
import requests

from os import path
from hashlib import md5
from datetime import datetime

country = sys.argv[1]
layer = sys.argv[2]
width = int(sys.argv[3])
height = int(sys.argv[4])
top = float(sys.argv[5])
bottom = float(sys.argv[6])
left = float(sys.argv[7])
right = float(sys.argv[8])

cid = 'bgeoqg7'
privatekey = 'pgyw84lkjf8k'

code = md5(datetime.utcnow().strftime('%Y%m%d') + privatekey).hexdigest()

infojson = requests.get('http://gma.foreca.com/info-json.php?c=%s&cid=%s&lon=%s&lat=%s' % (code, cid, (left+right)/2, (top+bottom)/2)).json()
passcode = infojson['pid']['c']

for layerno in infojson:
  if infojson[layerno].get("pname") == layer:
    break
else:
  print "layer not found"
  sys.exit(3)

for timestamp in infojson[layerno]['UTC']:
  timestamp = str(timestamp)
  if not timestamp.isdigit():
    print "timestamp isn't a digit... something scary is going on..."
    sys.exit(4)
  filename = "%s.png" % timestamp[2:-2]
  filepath = path.join("/var/www/html/radar/", country, filename)
  if path.exists(filepath):
    print "skipping", filepath
    continue
  # Processed images end up elsewhere...
  filepath = path.join("/var/local/radar/working/", country, filename)
  r = requests.get('http://gma.foreca.com/tile.php?z=6&t=%s&p=%s&c=%s&cid=%s&bbox=%s,%s,%s,%s&transparent=TRUE' % (timestamp, layerno, passcode, cid, left, bottom, right, top))
  if r.status_code == 200:
    with open(filepath, 'wb') as f:
      for chunk in r.iter_content():
        f.write(chunk)
