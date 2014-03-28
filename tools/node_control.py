#!/usr/bin/env python

__author__ = 'sunyu'
__date__ = '2013-11-05'

import sys

import memcache
import MySQLdb

def main():
    host = '127.0.0.1'
    passwd = ''
    node_num = 0
    #get control node host and mysql passwd
    try:
        host = sys.argv[1]
        passwd = sys.argv[2]
    except Exception, e:
        print 'Argument error: ', e
        return
    #get control node memcache NodeMaxNum
    try:
        mc = memcache.Client([host+':11211'])
        node_num = mc.get('CreeperQuotas').get('NodeMaxNum')
    except Exception, e:
        if not node_num:
            print 'no license'
            return
    #get node num in creeper database       
    try:
        conn = MySQLdb.connect(host=host, db='creeper', user='creeper', passwd=passwd)
        cur = conn.cursor()
        sql = r'select count(id) from node_manage_node'
        cur.execute(sql)
        retval = cur.fetchall()[0][0]
        if retval < node_num:
            print 'ok'
        else:
            print 'license but more than node number'

        cur.close()
        conn.close()
    except Exception, e:
        print 'Error: ', e

if __name__ == '__main__':
    main()

