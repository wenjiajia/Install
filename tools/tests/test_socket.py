#!/usr/bin/env python
# vim: tabstop=4 shiftwidth=4 softtabstop=4

# Copyright 2012 Beixinyuan(Nanjing), All Rights Reserved.
#
#    Licensed under the Apache License, Version 2.0 (the "License"); you may
#    not use this file except in compliance with the License. You may obtain
#    a copy of the License at
#
#         http://www.apache.org/licenses/LICENSE-2.0
#
#    Unless required by applicable law or agreed to in writing, software
#    distributed under the License is distributed on an "AS IS" BASIS, WITHOUT
#    WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the
#    License for the specific language governing permissions and limitations
#    under the License.


"""Testing for socket server."""

import socket

message = 'TRACE#'

sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)

server_address = ('localhost', 9267)

sock.connect(server_address)

try:
    sock.sendall(message)
    while True:
        data = sock.recv(64)
        print data
finally:
    sock.close()
