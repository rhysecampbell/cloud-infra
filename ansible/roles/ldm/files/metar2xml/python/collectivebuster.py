#!/usr/bin/python

__author__="Tim Sobolewski (TJSO)"
__date__ ="$20 January 2014 23:58$"
__version__="2.6"

# Most recent change: added sleep period after directory listing for JoeS
# Should allow all files to finish writing

import datetime
import sys
import ConfigParser
import os
import shutil
import filewriterclass
import time

# Initialize variables
debug = None
inputdir = None
removebreaks = True
filterNILmetars = True
outputdir = []
headerlist= []
headerstotal = 0
headersprocessed = 0


def openfile(filenametemp):
    # Handles opening file and returns handle to the file
    if debug:
        print ('openfile()')
        print ('Filename: %s' % filenametemp)
    try:
        filetemp = open ( filenametemp )
        #logwrite.logentry('Open file: %s' % filenametemp)
    except Exception, e:
        if debug:
            # File does not exist
            print ('Cannot open file for reading. File name: %s' % filenametemp)
            print e
            logwrite.logentry('ERROR: Cannot open file for reading. File name: %s' % filenametemp)
            logwrite.logentry('ERROR: %s' % e)
        return False

    return filetemp
# End openfile()

def readheaderlist(filenametemp):
    # Handles opening file and returns a list of header strings
    if debug:
        print ('readheaderlist()')
        print ('Filename: %s' % filenametemp)
    headerlisttemp = []
    try:
        filetemp = open ( filenametemp )
    except Exception, e:
        if debug:
            # File does not exist
            print ('Cannot open file for reading. File name: %s' % filenametemp)
            print e
            logwrite.logentry('ERROR: Cannot open file for reading. File name: %s' % filenametemp)
            logwrite.logentry('ERROR: %s' % e)
        return None

    while 1:
        line = filetemp.readline()
        if not line:
            break
        stripedline = line.strip()
        if len(stripedline) > 0 and stripedline[0] <> ';':
            headerlisttemp.append(stripedline)

    return headerlisttemp

def getsegment(filetemp):
    # Reads a segment (header and data) from the file and returns buffer containing the segment
    if debug:
        print ('getsegment()')

    buffer = ''

    fileline = filetemp.readline()

    safetyvalve = 0

    while fileline:
        # if fileline.count(SOH) > 0:
        fileline = filetemp.readline()
        while fileline.count(ETX) == 0 and safetyvalve < 100000:
            buffer = buffer + fileline;
            fileline = filetemp.readline()
            safetyvalve = safetyvalve + 1
        break
        # else: fileline = filetemp.readline()
    return buffer
# End getsegment()

def decodesegment(segtemp):
    # Extracts header and data, calls extractmetars() on data if necessary, returns list of METARs when complete
    if debug:
        print ('decodesegment()')

    # Just for tracking counts
    global headerstotal
    global headersprocessed

    metars = None

    endofheader = segtemp.find(CR)
    header = segtemp[:endofheader]
    headerstotal = headerstotal + 1
    header = header.strip()
    if header.isdigit():
        if debug:
            print ('Unisys Header: %s' % header)
        segtemp2 = segtemp[endofheader:].strip()
        metars = decodesegment(segtemp2)
    else:
        if debug:
            print ('Header: %s' % header)
        if header.startswith(headerlist) or len(headerlist) == 0:
            headersprocessed = headersprocessed + 1
            if debug:
                print ('Process header: %s' % header)
            data = segtemp[endofheader:].strip()

            # Determine if it's a packet of METARs
            if data[:5]=='METAR' or data[:5]=='SPECI':
                #print header
                metars = extractmetars(data)
            else:
                # Header is in header list but content isn't METARs
                logwrite.logentry('ERROR: Decode error --> Header: %s' % header)
            if debug:
                if metars == None:
                    print ('decodesegment:   0 METARs returned.')
                else: print ('decodesegment:   %d METARs returned.' % len(metars))
        #print header

    return metars

# End decodesegment()

#def decodesegment(segtemp):
#    # Extracts header and data, calls extractmetars() on data if necessary, returns list of METARs when complete
#    if debug:
#        print ('decodesegment()')
#
#    # Just for tracking counts
#    global headerstotal
#    global headersprocessed
#
#    metars = None
#
#    endofheader = segtemp.find(CR)
#    header = segtemp[:endofheader]
#    headerstotal = headerstotal + 1
#    if debug:
#        print ('Header: %s' % header)
#    if header.startswith(headerlist) or len(headerlist) == 0:
#        headersprocessed = headersprocessed + 1
#        if debug:
#            print ('Process header: %s' % header)
#        data = segtemp[endofheader:].strip()
#
#        # Determine if it's a packet of METARs
#        if data[:5]=='METAR' or data[:5]=='SPECI':
#            #print header
#            metars = extractmetars(data)
#        else:
#            # Header is in header list but content isn't METARs
#            logwrite.logentry('ERROR: Decode error --> Header: %s' % header)
#        if debug:
#            if metars == None:
#                print ('decodesegment:   0 METARs returned.')
#            else: print ('decodesegment:   %d METARs returned.' % len(metars))
#    #print header
#
#    return metars
#
## End decodesegment()

def extractmetars(data):
    # Extracts individual METARs from data, calls buildmetars or splitmetars as appropriate, returns list of METARs when complete
    if debug:
        print ('extractmetars()')
    linelengthCR = data.find(CR)
    linelengthLF = data.find(LF)
    returnlist = []

    if linelengthCR == -1:  # No carrage returns
        if linelengthLF == -1:  # No carrage returns and no linefeeds
            # Single METAR, single line
            returnlist.append(data.strip(' ='))
        else:  # No carrage returns but with linefeeds
            # Either a LF-seperated multiline METAR or needs METAR tacked on to the front
            lfpos = data.find(LF)
            if lfpos == 5 or lfpos == 13:
                # Obs have METAR or SPECI header and have to be concatinated
                returnlist = buildmetars(data, LF)
            else:  # Multiple METARs with linefeed linebreaks or METARs with linefeed linebreaks
                returnlist = splitmetars(data, LF)
    elif linelengthCR == 5 or linelengthCR == 13:
        returnlist = buildmetars(data, CR)
    else:
        returnlist = splitmetars(data, CR)

    if debug: print ('extractmetars:   %d METARs returned.' % len(returnlist))

    return returnlist
# End extractmetars()

def splitmetars(data, sepchar):
    # Seperates METARs from a group, calls rbreak to remove linebreak if necessary, returns list of METARs when complete
    if debug:
        print ('splitmetars')
    returnlist = []
    obcount = data.count(EofM)
    if obcount == 1:
        returnlist.append(rbreak(data).strip('='))
    else:
        for n in range(obcount):
            eqpos = data.find(EofM)
            tempmetar = data[:eqpos]
            # Process tempmetar
            if removebreaks and tempmetar.count(sepchar) > 0:
                returnlist.append(rbreak(tempmetar))
            else:
                returnlist.append(tempmetar)
            data = data[eqpos+1:].strip()

    if debug: print ('splitmetars:   %d METARs returned.' % len(returnlist))

    return returnlist
# End splitmetars()

def buildmetars(data, sepchar):
    # Takes heading of 'METAR' or 'SPECI' and reassembles METARs, returns list of METARs
    if debug:
        print ('buildmetars()')
    returnlist = []
    linelength = data.find(sepchar)
    obtype = data[:5]
    data = data[linelength:].strip()
    obcount = data.count(EofM)

    for n in range(obcount):
        eqpos = data.find(EofM)
        if data[:5] <> obtype:
            tempmetar = obtype + ' ' + data[:eqpos]
        else: tempmetar = data[:eqpos]
        # Process tempmetar
        if removebreaks and tempmetar.count(sepchar) > 0:
            returnlist.append(rbreak(tempmetar))
        else:
            returnlist.append(tempmetar)
        data = data[eqpos+1:].strip()

    if debug: print ('buildmetars:   %d METARs returned.' % len(returnlist))

    return returnlist
# End buildmetars()

#def rbreak2(data):
#    # Remove line breaks from METARs, returns single METAR without linebreak
#    if debug:
#        print ('rbreak2()')
#    ob = None
#    crcount = data.count(CR)
#    if crcount > 0:
#        crpos = data.find(CR)
#        ob = data[:crpos]
#        data = data[crpos:].strip()
#        for i in range(crcount):
#            crpos = data.find(CR)
#            if crpos == -1:
#                ob = ob.strip() + ' ' + data.strip()
#            else:
#                ob = ob.strip() + ' ' + data[:crpos].strip()
#            data = data[crpos:].strip()
#    else:
#        crcount = data.count(LF)
#        crpos = data.find(LF)
#        ob = data[:crpos]
#        data = data[crpos:].strip()
#        for i in range(crcount):
#            crpos = data.find(LF)
#            if crpos == -1:
#                ob = ob.strip() + ' ' + data.strip()
#            else:
#                ob = ob.strip() + ' ' + data[:crpos].strip()
#            data = data[crpos:].strip()
#
#    return ob.strip()
## End rbreak2()

def rbreak(data):
    # Remove line breaks from METARs, returns single METAR without linebreak
    if debug:
        print ('rbreak()')
    ob = []

    charcount = len(data)
    for i in range(charcount):
        if data[i] == CR or data[i] == LF:
            pass
        else:
            ob.append(data[i])

    ob = "".join(ob)

    ob = ob.split()

    count = len(ob)
    newob = ''

    for j in range(count):
        newob = newob + ' ' + ob[j]

    return newob.strip()
# End rbreak()

def filternil(tempmetarlist):
    # Removes METARs containing the word NIL(preceeded by a space), returns list of non-NIL METARs
    if debug:
        print ('filternil()')
        i = 0
    newlist = []
    for tempmetar in tempmetarlist:

        if tempmetar.count(' NIL') == 0:
            newlist.append(tempmetar)
        else:
            if debug:
                print ('---------------------------------: ' + tempmetar)
                i = i + 1
    if debug:
        print ('filternil:   %d observations deleted.' % i)
        print ('filternil:   %d METARs returned.' % len(newlist))

    tempmetarlist = None
    return newlist
# End testforNIL

def outputfile(buffertemp):
    # Converts list of METARs into string of METARs seperated by a cr, and writes them to the output directories

    # Turn the list into a string for writing to a file
    buffertemp = chr(10).join(buffertemp)
    # Initialize variable to False
    success = False

    for outpath in outputdir:
        if timestampoutputfile:

            stamp = datetime.datetime.utcnow().strftime('%Y%m%d%H%M%S')

            destfilename = outpath + '/' + stamp + '_' + filename
        else:
            destfilename = outpath + '/' + filename
        print ('--> %s' % destfilename)

        try:
            outfile = open( destfilename, "w")
            outfile.write(buffertemp)
            outfile.write(chr(10))
            outfile.close()
            if well:
                writealivewell(wellfile, 'W')
            success = True
        except Exception, e:
            print e

    return success

# End outputfile()

#def gettimestampfromfilename(filenametemp):
#    # Return first 14 characters
#    returnvalue = filenametemp[:14]
#    if returnvalue.isnumeric():
#        return returnvalue
#    else: return None
## End parsefilename function

def writealivewell(filenametemp, buffertemp=None):
    # Function for writing ALIVE and WELL files
    try:
        file = open( filenametemp, "w")
        if buffertemp <> None:
            file.write(buffertemp)
        file.close()
    except Exception, e:
        logwrite.logentry('ERROR: Cannot write file %s' % filenametemp)
        logwrite.logentry('ERROR: %s' % e)
        print e
# End writealivewell()

if __name__ == "__main__":

    print
    print ('collectivebuster started at %s.' % datetime.datetime.utcnow().strftime('%Y-%m-%d %H:%M:%SZ'))
    print ('Initialize collectivebuster.py  Version: %s' % __version__)

    if len(sys.argv) == 1:
        try:
            scriptname = sys.argv[0]
            extindex = scriptname.index('.py')
            scriptname = scriptname[:extindex]

            inifile = scriptname + '.ini'
        except Exception,  e:
            print e
    else:
        inifile = sys.argv[1]

    # Parse ini file
    iniparser = ConfigParser.ConfigParser()
    try:
        iniparser.read(inifile)
        print ("Load ini file: %s" % inifile)
        if iniparser.has_section('settings'):
            if iniparser.has_option('settings','debug'):
                debug = iniparser.getboolean('settings', 'debug')
            if iniparser.has_option('settings','removebreaks'):
                removebreaks = iniparser.getboolean('settings', 'removebreaks')
            if iniparser.has_option('settings','filterNILmetars'):
                filterNILmetars = iniparser.getboolean('settings', 'filterNILmetars')
            if iniparser.has_option('settings','timestampoutputfile'):
                timestampoutputfile = iniparser.getboolean('settings', 'timestampoutputfile')
            if iniparser.has_option('settings','sleep_time'):
                sleep_time = int(iniparser.get('settings', 'sleep_time'))
                if sleep_time < 0: sleep_time = 0
            else: sleep_time = 0
        if iniparser.has_section('input'):
            if iniparser.has_option('input','inputdir'):
                inputdir = iniparser.get('input', 'inputdir')
            if iniparser.has_option('input','headerfile'):
                headerfile = iniparser.get('input', 'headerfile')
        if iniparser.has_section('output'):
            if iniparser.has_option('output','processedtarget'):
                processedtarget = iniparser.get('output', 'processedtarget')
            else: processedtarget = None
            # Handle an unknown number of output files
            if len(outputdir)==0 or outputdir[0]==None:
                outputdir = []
                if iniparser.has_option('output','logfile'):
                    logfile = iniparser.get('output', 'logfile')
                if iniparser.has_option('output','outputdir'):
                    outputdir.append(iniparser.get('output','outputdir'))
                notdone = True
                i = 1
                while notdone:
                    option_n = ('outputdir%d' % i)
                    if iniparser.has_option('output',option_n):
                        outputdir.append(iniparser.get('output',option_n))
                        i = i + 1
                    else: notdone = False
                if iniparser.has_option('output','alivefile'):
                    alivefile = iniparser.get('output', 'alivefile')
                    alive = True
                else: alive = False
                if iniparser.has_option('output','wellfile'):
                    wellfile = iniparser.get('output', 'wellfile')
                    well = True
                else: well = False

    except Exception,  e:
        print ('Valid INI file not available.')

    if logfile <> '':
        logwrite = filewriterclass.Filewriter(logfile, 'datestamp')
    else: sys.exit(1)

#    debug = False
#
#    removebreaks = True
#    filterNILmetars = True
#    outputfilename = '/TEST4/outputfile.txt'

    # Start of heading
    SOH = chr( 1 )
    # End of text
    ETX = chr( 3 )
    # Carriage return
    CR = chr( 13 )
    # Linefeed
    LF = chr( 10 )
    # EofM (end of METAR)
    EofM = '='


    if len(inputdir) > 0 and len(outputdir) > 0:
        sourcepath = inputdir
        # Be sure source path isn't in the destination path
        if outputdir.count(sourcepath) >= 1:
            print ('source and destination must be different')
        else:
            # headerlist needs to be a 'tuple' so it is converted here
            headerlist = tuple(readheaderlist(headerfile))

            for (path, dirs, files) in os.walk(sourcepath):
                if len(files) > 0:
                    print('Sleep %d' % sleep_time)
                    time.sleep(sleep_time)
                for filename in files:
                    # Reset to zero for each file
                    headerstotal = 0
                    headersprocessed = 0
                    

#                    if expecttimestamp:
#                        filenametimestamp = gettimestampfromfilename(filename)
                    file = openfile(path + filename)

                    segment = getsegment(file)

                    segment = segment.strip()

                    i = 0
                    j = 0
                    metarlist = []
                    while len(segment) <> 0 and i < 100000:

                        mylist = decodesegment(segment)
                        if mylist <> None:
                            if filterNILmetars:
                                mylist = filternil(mylist)
                            metarlist.extend(mylist)
                            if debug:
                                for ob in mylist:
                                    i = i + 1
                                    print ('#%d: %s' % (i, ob))

                        j = j + 1
                        print ('#%d' % (j))
                        segment = getsegment(file)

                        segment = segment.strip()

                    file.close()
                    successful = outputfile(metarlist)

                    if successful:
                        print ('%d METARs processed.' % len(metarlist))
                        if processedtarget == None or processedtarget == '':
                            try:
                                os.remove(path + filename)
                                print ('Delete %s' % path + filename)
                            except Exception,  e:
                                print e
                        else:
                            shutil.move(path + filename, processedtarget + '/' + filename)
                            print ('Move processed file %s --> %s' % (path + filename, processedtarget))
                            #shutil.copyfile(path + filename, processedtarget + '/' + filename + '.' + str(time.time()))
                            #os.unlink(path + filename)





                    i = 0
                    if debug:
                        for ob in metarlist:
                            i = i + 1
                            print ('#%d: %s' % (i, ob))

                    print ('Complete: %s' % filename)

                    logwrite.logentry('File: %s  HeadersTotal: %d  HeadersProcessed: %d  METARs: %d' % (filename, headerstotal, headersprocessed, len(metarlist)))
            if alive:
                writealivewell(alivefile, 'A')


    print
    print ("Script completed at %s." % datetime.datetime.utcnow().strftime('%Y-%m-%d %H:%M:%SZ'))

#; this is an INI file
#[settings]
#debug        = True
#; Remove linebreaks in METARs
#removebreaks = True
#; Remove METARs containing the phrase ' NIL'
#filterNILmetars = True
#; Prepends output file with yyyymmddhhMMss_
#timestampoutputfile = True
#
#; The script will wait sleep_time seconds to process files after seeing them
#; This will insure that files have finished writing
#sleep_time   = 10
#
#[input]
#inputdir      = /opt/datain/
#headerfile    = /opt/headerfile.txt
#
#[output]
#outputdir     = /opt/dataout/
#;outputdir1    = /opt/noaaportmetarproc/bustedtobesplit/
#;outputdir2    = /mnt/winshare/noaaport/bustedmetars/
#
#logfile       = /opt/collectivebuster.log
#; System will update the ALIVE file every time the script finishes
#alivefile     = /opt/collectivebuster_ALIVE.txt
#; System will update the WELL file every time the script writes a file of METARs
#wellfile      = /opt/collectivebuster_WELL.txt
#
#; Move processed files to this directory
#processedtarget = /opt/dataout1/

