#coding=utf-8 
__author__ = 'wenjiajia'
__date__ = '2013-07-29'
__version__ = '1.0.0'

import logging,os,subprocess,datetime,md5,sys,MySQLdb

# log settings
log_level = logging.INFO
logging.basicConfig(filename = os.path.join(os.getcwd(), 'add_host.log'), level = log_level)
log = logging.getLogger('add_host')
log.setLevel(log_level)

# global variables
USER_NAME = 'creeper'
DB_NAME = 'creeper'

# functions
def get_cmd_result(cmd):
    """
    get the output from the shell
    :param cmd:
    :return: result_res[0:num]
    """
    result = subprocess.Popen(cmd, shell=True, close_fds=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
    result_res = result.stdout.readline()
    num = len(result_res) - 1
    return result_res[0:num]
def get_connection(host,passwd):
    """
    get connection to mysql
    :param host: passwd:
    :return: conn

    """
    conn = None
    try:
        conn = MySQLdb.connect(host=host,passwd=passwd,user=USER_NAME,db=DB_NAME)
    except MySQLdb.Error , e:
        log.error("%d: %s" % (e.args[0] ,e.args[1]))
    return conn
def get_cursor(conn):
    """
    get the cursor from connection
    :param conn:
    :return: cursor
    """
    cursor = None
    try:
        cursor = conn.cursor()
    except MySQLdb.Error ,e :
        log.error("%d: %s" % (e.args[0] ,e.args[1]))
    return cursor
def add_host_into_db(cursor,conn):
    """
    insert host into database
    :param cursor: conn:
    :return:
    """
    sql = "SELECT * FROM node_manage_node"
    node = sys.argv[1]
    try:
        rs = cursor.execute(sql)
        numrows = int(cursor.rowcount)
        host_name_list = []
        for i in range(numrows):
            row = cursor.fetchone()
            host_name_list.append(row[2])
        if host_name_list.count(hostname_result) == 0 :
            value = (uuid,hostname_result,ipv4_result,node,created_at)
            cursor.execute("insert into node_manage_node (uuid,name,ip,passwd,type,created_at) values ('%s','%s','%s','','%s','%s')" % value)
            log.info('you have inserted one line into database %s' % created_at)
        else:
            log.error('hostname has been exist %s' % created_at)
        conn.commit()
    except MySQLdb.Error ,e:
        conn.rollback()
        log.error('rollback %s' % created_at)
def close_cursor(cursor):
    """
    close the cursor
    :param cursor:
    :return:
    """
    try:
        if cursor :
            cursor.close()
    except MySQLdb.Error ,e:
        log.error('cursor close error %s' % created_at)
def close_connection(conn):
    """
    close the connection
    :param conn:
    :return:
    """
    try:
        if conn :
            conn.close()
    except MySQLdb.Error , e:
        log.error('conn close error %s' % created_at)

# local variables
# get the hostname of compute node
hostname_result = get_cmd_result('hostname')
# get the compute node ipv4
ipv4_result = get_cmd_result('ifconfig eth0 | grep "inet " | awk \'{print $2}\' | awk -F \':\' \'{print $2}\'')
created_at = datetime.datetime.now().utcnow()
uuid = md5.new(str(created_at)).hexdigest()
# get the mysql host ip
if os.path.exists('/var/mysql_nic.ip'):
    control_pri_ip_result = get_cmd_result('cat /var/mysql_nic.ip')
else:
    log.error('cannot find the file /var/mysql_nic.ip %s' % created_at)
    sys.exit(1)
# get mysql password
if os.path.exists('/tmp/mysql_passwd.log'):
    mysql_passwd_result = get_cmd_result('cat /tmp/mysql_passwd.log')
else:
    log.error('cannot find the file /tmp/mysql_passwd.log %s' % created_at)
    sys.exit(1)

connection = get_connection(control_pri_ip_result,mysql_passwd_result)
cursor = get_cursor(connection)
add_host_into_db(cursor ,connection)
close_cursor(cursor)
close_connection(connection)
