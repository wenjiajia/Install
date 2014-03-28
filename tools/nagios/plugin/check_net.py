#! /usr/bin/env python
# -*- coding: utf-8 -*-
# vim: tabstop=4 shiftwidth=4 softtabstop=4

import sys
import argparse
import time
import subprocess
import re

# common cmd process
def cmdprocess(cmdline, *args, **kargs):

    if len(kargs) > 0:
        bashCommand = cmdline % kargs
    elif len(args) > 0:
        bashCommand = cmdline % args
    else:
        bashCommand = cmdline

    process = subprocess.Popen(bashCommand, stdout=subprocess.PIPE, shell=True)
    output = process.communicate()[0].split('\n')

    if output is None:
        print "The cmd running error.cmdprocess(): bashCommand %s" % bashCommand
        sys.exit(1)

    return output[0]

# Get the net Rx and Tx from filename
def readNet(filename,args):
    '''
    return val:
        { "eth0": (Rx,Tx)}
    '''
    regex=r'\s*(?P<device>[-\w]+):(?P<data>.*)$'
    result={}

    with open(filename,'r') as f:
        for line in f:
            reline = re.search(regex, line)
            if reline and reline.group("device") in args.devlist:
                Rx = reline.group("data").split()[0]
                Tx = reline.group("data").split()[8]
                result[reline.group("device")]=(Rx,Tx)
    return result

# cal net stat
def process(args,filename):
    '''
    01 get the args values
    02 get old values from /proc/net/dev
    03 time.sleep
    04 get new values from /proc/net/dev
    05 cal the values
    06 format return
    { "eth0":(Rx,Tx),
      "eth1":(Rx,Tx)
      ...
    }
    '''

    args.devlist=args.devices.split(',')
    sleeptime = args.time

    result={}
    notDevs=[]

    oldVal=readNet(filename,args)

    time.sleep(sleeptime)

    newVal=readNet(filename,args)

    for device in args.devlist:
        if newVal.has_key(device):
            result[device] = ((int(newVal[device][0])-int(oldVal[device][0]))/sleeptime,
                              (int(newVal[device][1])-int(oldVal[device][1]))/sleeptime)
        else:
            notDevs.append(device)

    for notDev in notDevs:
        #print "The device %s is not exist" % notDev
        args.devlist.remove(notDev)
    return result

# alert Warning or Critical
def alert(args,data):

    warning = args.warning
    critical = args.critical

    regex = r'\s*(\w+):.(?P<val>\d+)(?P<units>\w*)'

    ''' Ex data: Speed: 100Mb/s'''

    for device in args.devlist:
        res = re.match(regex, cmdprocess("ethtool %s | grep 'Speed'",device))
        if res is None:
            continue
        maxVal = res.group("val")
        unit = res.group("units")
        netstat = bytesUtils(sum(data[device]))
        if unit in netstat:
            try:
                per = arrondir(float(netstat.rstrip(unit))/float(maxVal)*100)
            except ZeroDivisionError:
                print "[Error] the data of net stat is Zero."
            if per >= critical:
                return "CRITICAL"
            if per >= warning:
                return "WARNING"

    return "OK"

def arrondir(arg):
        result='%.2f' % arg
        return result

# format the data from byte to KB or MB
def bytesUtils(arg):

    size=len('%.f' % arg)
    if size >= 10:
        result = float(arg)*8/1024/1024/1024
        result=arrondir(result)
        return "%sGb" % result
    elif size >= 7:
        result = float(arg)*8/1024/1024
        result=arrondir(result)
        return "%sMb" % result
    elif size >= 4:
        result = float(arg)*8/1024
        result=arrondir(result)
        return "%sKb" % result
    else:
        return "%sb" % (float(arg)*8)

# format the output
def output(args, data):
    '''
    require data:
    NET OK - eth0:122.4B/146.3B,lo:9.8B/9.8B,virbr0:0.0B/0.0B (Rx/Tx)
    |'eth0_in'=128306141c;w;c;; 'eth0_out'=153375083c;w;c;; 'lo_in'=10261885c;w;c;; 'lo_out'=10261885c;w;c;;
    'virbr0_in'=0c;w;c;; 'virbr0_out'=0c;w;c;;
    '''
    perfData=""
    outData=""

    for device in args.devlist:
        perfData+="\'%s_in\'=%sc;%s;%s;;" % (device,
                                         data[device][0], args.warning, args.critical) \
                   +"\'%s_out\'=%sc;%s;%s;;" % (device,
                                          data[device][1], args.warning, args.critical)
        outData+= "%s:%s/%s," % (device,
                                          bytesUtils(data[device][0]),
                                          bytesUtils(data[device][1])
                                          )
    return "NET %s - %s (Rx/Tx) | %s" % (alert(args,data),outData[:-1],perfData)

# init the parser
def initParser():
    '''
    cmd -d eth0|eth1 -w 80 -c 90 -t 2
    -d default (all)
    -t default 3s
    '''
    parser = argparse.ArgumentParser(prog='check_net.py',
                                     description="Checking the net device state...")

    parser.add_argument('-d','--device',dest="devices",
                        default='eth0,eth1,br-ex',
                        help="net devices seperated by comma(',').")
    parser.add_argument('-t','--time', dest="time",type=int,
                        default='3',
                        help='sleeping time for calculate.')
    parser.add_argument('-w','--warning', dest="warning", help='warning threshold.', required=True)
    parser.add_argument('-c','--critical', dest="critical", help='critical threshold.', required=True)

    return parser

def main():

    filename = "/proc/net/dev"

    # 01 process the user input
    parser=initParser()
    args = parser.parse_args()

    # 02 cal net stat
    data = process(args,filename)

    # 03 output info
    print output(args,data)

if __name__ == "__main__":
    main()
