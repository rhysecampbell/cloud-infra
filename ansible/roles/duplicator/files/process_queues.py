#!/usr/bin/env python
import os
import socket
import jinja2
import requests

from subprocess import call, Popen

templateLoader = jinja2.FileSystemLoader( searchpath="/etc/vaisala-config/do-sendcc/" )
templateEnv = jinja2.Environment( loader=templateLoader )
TEMPLATE_FILE = "template.conf.j2"
template = templateEnv.get_template(TEMPLATE_FILE)


def create_config(queue, addr):
    conffile = '/etc/vaisala-config/do-sendcc/auto/%s-%s.conf' % (queue, addr)
    with open(conffile, 'wb') as f:
        f.write(template.render(queue=queue, addr=addr))

def create_directory(directory):
    if not os.path.exists(directory):
        os.makedirs(directory)
    
def create_links(source, dest):
    for file in os.listdir(source):
        try:
            os.link("%s/%s" % (source, file), "%s/%s" % (dest, file))
        except OSError: # Link already exists
            continue

def fire_sendcc(queue, addr):
    try:
        requests.get('http://%s' % addr, timeout=1)
    except requests.exceptions.RequestException as e:
        print "Couldn't connect: %s" % str(e)
        return
    conf = "auto/%s-%s.conf" % (queue, addr)
    if call(["pgrep", "-f", conf]) == 0:
        print conf, " already running"
        return False
    create_config(queue, addr)
    print "starting ", conf
    Popen(["/usr/local/bin/sendcc", "-c", conf])

r = requests.get('http://localhost:4001/v2/keys/queues?recursive=true')
for node in r.json()['node']['nodes']:
    queue = node['key'][len('/queue/')+1:]
    print "queue name is %s" % queue
    directory = '/var/local/%s' % queue
    tmpdirectory = '%s/temp/' % directory
    create_directory(directory)
    create_directory(tmpdirectory)

    call(["find", directory, "-maxdepth", "1", "-type", "f", "-exec", "mv", "{}",  tmpdirectory, ";"])
    if 'nodes' not in node:
        continue
    for host in node['nodes']:
        ip = host['key'][len(node['key']) + 1:]
        print "ip is %s" % ip
        port = int(host['value'])
        print "port is %s" % port
        addr = "%s:%i" % (ip, port)
        print "dealing with", addr
        addrdirectory = "%s/%s" % (directory, addr)
        errordirectory = "%s/error"
        create_directory(addrdirectory)
        create_directory(errordirectory)
        create_links(tmpdirectory, addrdirectory)
        fire_sendcc(queue, addr)
    print "finished dealing with subscribers"
    call(["find", tmpdirectory, "-maxdepth", "1", "-type", "f", "-delete"])
    print "finished find -delete"

print "done"
