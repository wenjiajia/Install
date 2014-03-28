#! /usr/bin/env python
# -*- coding: utf-8 -*-
# vim: tabstop=4 shiftwidth=4 softtabstop=4

import fcntl
import json
import os
import re
import socket
import struct

from httplib2 import Http


headers = {
    "accept": "application/json",
    "content-type": "application/json"
}

import json
from httplib2 import Http


headers = {
    "accept": "application/json",
    "content-type": "application/json"
}

def service_status(service_name):
    output = os.popen('service '+service_name+' status').read()
    if output.find('unrecognized service') != -1:
        return 1
    elif output.find('stop/waiting') != -1:
        return 2
    elif output.find('start/running') != -1:
        return 3
    return 0


class RequestException(Exception):

    def __init__(self, resq, msg=None):
        super(RequestException, self).__init__()

        if msg:
            self.msg = "Request Error staus: %(status)"

        self.resq = resq

    def __repr__(self):
        return self.msg % {"status": resq.get("status", "404")}


def getUrl(url, method="GET", header=None, data=None):
    """ Return Url response.

        :param url: request url
        :param method: request mothod, GET|POST
        :param data: post request body
        :raise: RequestException"""

    body = data

    if body :
        body = json.dumps(data)

    if header:
        headers.update(header)

    return json.loads(_do_request(url, method, headers, body))

def _do_request(url, method, header, body):
    """ http request by httplib2 """

    try:
        resp, content = Http().request(url,
                                       method,
                                       headers=headers,
                                       body=body)
        if not resp or resp.get("status", "404") != "200":
            raise RequestException(resp)
    except RequestException, e:
        return '{}'
    return content


def check_port(address, port):
    """ check server port by socket """

    s = socket.socket()
    try:
        s.connect((address, port))
        return True
    except socket.error, e:
        return False


def check_file_content(filename, content):
    """ check file content """

    res = []
    with open(filename, 'r') as file:
        for line in file:
            res.append(re.search(content, line))

    return any(res)


def get_host_name():
    """ return hostname by socket """

    return socket.gethostname()


def get_ip_address(ifname):
    """ return host ip address """

    s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    return socket.inet_ntoa(
        fcntl.ioctl(
            s.fileno(),
            0x8915,  # SIOCGIFADD
            struct.pack('256s', ifname[:15])
            )[20:24]
        )
