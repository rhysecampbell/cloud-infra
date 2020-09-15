# To change this template, choose Tools | Templates
# and open the template in the editor.

__author__="Tim Sobolewski (TJSO)"
__date__ ="$Sep 1, 2010 11:34:13 AM$"
__version__="2.1"

# Last addition:  added writepidfile()

import os.path
import datetime
import os

debug = False

class Filewriter:
    "A simple class for creating & writting out various kinds of files"

#    filename = None

    # Initialize and create file by type
    def __init__(self, filename, nametype=None, debug = False):

        if debug:
            self.debug = True
        else:
            self.debug = False

        if nametype != None:
            nametype = nametype.upper()

        self.nametype = nametype

        if nametype == None:
            self.filename = filename

        elif nametype == "DATESTAMP" or nametype == "TIMESTAMP":
            self.setdsfilename(filename, nametype)

        elif nametype == "OTSNCD":
            self.filename = filename

        elif nametype == "INC":
            # use incrementing nametype
            print
        else:
            self.filename = filename
            self.nametype = None
    # End __init__ function

    def setdsfilename(self, filename, nametype):
            now = datetime.datetime.utcnow()
            if nametype == 'DATESTAMP':
                datestring = now.strftime('%Y%m%d')
            elif nametype == 'TIMESTAMP':
                datestring = now.strftime('%Y%m%d%H%M%S')

            if filename.count('.') > 0:
    #            print ("filename: %s" % filename)
                extindex = filename.rfind('.')
                filenametemp = filename[:extindex]
                ext = filename[extindex:]
                self.filename = ("%s_%s%s" % (filenametemp, datestring, ext))
            else:
                self.filename = filename + '_' + datestring
#            print ("filename: %s" % filename)


    def write(self, buffer=None):
        if self.nametype == 'DATESTAMP' or self.nametype == 'TIMESTAMP' or self.nametype == None:
            self.writefile(buffer)
#            try:
#                file = open( self.filename, "a")
#                if buffer <> None:
#                    file.write(buffer)
#                file.close()
#            except Exception as e:
#                print e
        elif self.nametype == 'OTSNCD':
            # Put code here to handle OTS/NCD and similar filetypes
            if os.path.exists(self.filename):
                # File already exists, do nothing
                if debug:
                    print ('File %s exists.' % self.filename)
                None
            else:
                if debug:
                    print ('File %s does not exist.' % self.filename)
                length = len(self.filename)
                if self.filename.endswith('.VOP'):
                    # Delete OTS or NCD file and write VOP file
                    delfile = self.filename
                    delfile = delfile[:length - 4] + '.OTS'
                    # If the OTS file exists, delete it
                    if os.path.exists(delfile):
                        self.removefile(delfile)
                    delfile = delfile[:length - 4] + '.NCD'
                    # If the NCD file exists, delete it
                    if os.path.exists(delfile):
                        self.removefile(delfile)
                    self.writefile(buffer)
                elif self.filename.endswith('.OTS'):
                    # Delete VOP file and write OTS file
                    delfile = self.filename
                    delfile = delfile[:length - 4] + '.VOP'
                    # If the VOP file exists, delete it
                    if os.path.exists(delfile):
                        self.removefile(delfile)
                    delfile = delfile[:length - 4] + '.NCD'
                    # If the NCD file exists, delete it
                    if os.path.exists(delfile):
                        self.renamefile(delfile, self.filename)
                    #if not os.path.exists(self.filename):
                    else:
                        self.writefile(buffer)
                elif self.filename.endswith('.NCD'):
                    # Delete VOP file and write OTS file
                    delfile = self.filename
                    delfile = delfile[:length - 4] + '.VOP'
                    # If the VOP file exists, delete it
                    if os.path.exists(delfile):
                        self.removefile(delfile)
                    delfile = delfile[:length - 4] + '.OTS'
                    # If the NCD file exists, delete it
                    if os.path.exists(delfile):
                        self.renamefile(delfile, self.filename)
                    #if not os.path.exists(self.filename):
                    else:
                        self.writefile(buffer)

        elif self.nametype == 'INC':
            # Put code here to handle incremental file naming
            print 'nametype = INC <not yet supported>'
    # End write function

    def removefile(self, filename=None):
        if filename == None:
            filename = self.filename
        try:
            os.remove(filename)
        except Exception as e:
            print e

    def renamefile(self, oldfile, newfile):
        try:
            os.rename(oldfile, newfile)
        except Exception as e:
            print e

    def writefile(self, buffertemp):
        try:
            file = open( self.filename, "a")
            if buffertemp <> None:
                file.write(buffertemp)
            file.close()
        except Exception as e:
            print e

    def logentry(self, buffertemp):
        datestring = datetime.datetime.utcnow().strftime('%Y%m%d%H%M%S')
        try:
            file = open( self.filename, "a")
            if buffertemp <> None:
                buffertemp = (datestring + ' : ' + buffertemp + '\n')
                file.write(buffertemp)
            file.close()
        except Exception as e:
            print e

# Creates a file containing the process identification number
# - Useful for killing a process or confirming that a process is running
    def writepidfile(self):
        filename = None
        try:
            if self.filename <> None:
                extindex = self.filename.index('.pid')
                if extindex > 0:
                    filename = self.filename[:extindex]
                else: filename = self.filename

        except Exception as e:
            print e
        if filename <> None and filename <> '':
            try:
                pid = os.getpid()
                self.filename = ('%s_%s.pid' % (filename, pid))
                file = open( self.filename, "w")
                if pid <> None:
                    file.write(str(pid))
                file.close()
                return pid
            except Exception as e:
                print ('Cannot write PID file.')
                print e


    def test(self):
        print ('filename: %s' % self.filename)
        print ('nametype: %s' % self.nametype)
    # End test function

# For debug
#x = Filewriter('/TEST2/testfiletxt', 'timestamp')
#x = Filewriter('/TEST2/ABCOBS.vop', 'otsncd')
#x.test()
#x.write()
#x = Filewriter('/TEST2/filewriterclass_test.pid')
#x.writepidfile()
#x.removefile('/TEST2/filewriterclass_test.pid')
