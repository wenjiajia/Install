#! /usr/bin/env python
# -*- coding: utf-8 -*-
# vim: tabstop=4 shiftwidth=4 softtabstop=4

""" voyage install shell unittest """

"""
Test list:
    [x] nagios bins exist
    [x] nagios confs correct
    [x] nagios settint correct
    [x] nagios services running
"""

import os
import ConfigParser
import re
import subprocess

import unittest

import utils

class TestNagiosIns(unittest.TestCase):
    """ Test nagios install shell """

    def setUp(self):
        """ Init assert conts """

        # host meta info
        self.hostname = utils.get_host_name()
        self.hostip = utils.get_ip_address("br-ex")

        # nagios base dir
        self.base_dir = "/usr/local/nagios/"

        # bins checks
        # nagios core bin check
        self.core_bin = ["bin/nagios"]
        # nagios nrpe bin check
        self.nrpe_bin = ["bin/nrpe"]
        # nagios ndo2db bin check
        self.ndo2db_bin = ["bin/ndo2db", "bin/ndomod.o"]
        # nagios plugins check
        self.plugin_bin =[
            "libexec/check_cpu.sh",
            "libexec/check_disk",
            "libexec/check_diskstat.sh",
            "libexec/check_mem.sh",
            "libexec/check_net.py",
            "libexec/check_procs"
        ]

        # cfgs check
        # nagios core cfgs check
        self.core_cfg = [
            "etc/cgi.cfg",
            "etc/nagios.cfg",
            "etc/resource.cfg",
            "etc/objects/hosts/"+self.hostname+".cfg"
        ]
        # nagios ndo2db cfgs check
        self.ndo2db_cfg = [
            "etc/ndo2db.cfg",
            "etc/ndomod.cfg"
        ]
        # nagios nrpe cfgs check
        self.nrpe_cfg = [
            "etc/nrpe.cfg"
        ]

        # setting checks
        # nagios core set check
        # nagios ndo2db set check
        self.kernMsgmnb = '16384000'
        self.kernMsgmni = '16384000'
        self.db_name = 'db_name=nagios'
        self.db_user = 'db_user=nagios'
        self.db_pass = 'db_pass=nagios'
        self.broker = 'broker_module'
        # nagios nrpe set check
        # nagios plugin set check

        # service checks
        # nagios initd checks
        self.initd = [
            "/etc/init.d/nagios",
            "/etc/init.d/ndo2db",
            "/etc/xinetd.d/nrpe"
        ]
        # service process check
        self.service_ps = {
            "core": '/usr/local/nagios/bin/nagios',
            "ndo2db": '/usr/local/nagios/bin/ndo2db',
            "nrpe": '/usr/sbin/xinetd'
        }
        # service ports check
        self.service_port = {
            "nrpe": 5666
        }

    def test_bins(self):
        """ Test nagios bins """

        bins = self.core_bin
        bins.extend(self.nrpe_bin)
        bins.extend(self.ndo2db_bin)
        bins.extend(self.plugin_bin)
        for bin in bins:
            bin_file = self.base_dir+bin
            self.assertTrue(os.path.lexists(bin_file))

    def test_cfg(self):
        """ Test nagios """

        cfgs = self.core_cfg
        cfgs.extend(self.ndo2db_cfg)
        cfgs.extend(self.nrpe_cfg)
        for cfg in cfgs:
            cfg_file = self.base_dir+cfg
            self.assertTrue(os.path.lexists(cfg_file))

    def test_core_set(self):
        """ Test nagios core setting """

        filename = (self.base_dir
                    +"etc/objects/hosts/"
                    +self.hostname
                    +".cfg")
        self.assertTrue(utils.check_file_content(filename,
                                                 self.hostname)
                       )
        self.assertTrue(utils.check_file_content(filename,
                                                 self.hostip)
                       )

    def test_ndo2db_set(self):
        """ Test nagios ndo2db setting """

        msgmnb = "/proc/sys/kernel/msgmnb"
        msgmni = "/proc/sys/kernel/msgmni"

        self.assertTrue(utils.check_file_content(msgmnb,
                                                 self.kernMsgmnb)
                       )
        self.assertTrue(utils.check_file_content(msgmni,
                                                 self.kernMsgmni)
                       )

        ndo2db_file = self.base_dir+"etc/ndo2db.cfg"

        self.assertTrue(utils.check_file_content(ndo2db_file,
                                                 self.db_name)
                       )
        self.assertTrue(utils.check_file_content(ndo2db_file,
                                                 self.db_user)
                       )
        self.assertTrue(utils.check_file_content(ndo2db_file,
                                                 self.db_pass)
                       )

        nagios_file = self.base_dir+"etc/nagios.cfg"

        self.assertTrue(utils.check_file_content(nagios_file,
                                                 self.broker)
                       )

    def test_nrpe_set(self):
        """ Test nagios nrpe setting """

        nrpe_file = "/etc/xinetd.d/nrpe"

        self.assertTrue(utils.check_file_content(nrpe_file,
                                                 self.hostip)
                       )

    def test_service_initd(self):
        """ Test service initd """

        for initd in self.initd:
            self.assertTrue(os.path.lexists(initd))

    def test_service_ps(self):
        """ Test service ps """

        for ps in self.service_ps.values():
            self.assertIsNotNone(
                subprocess.check_output('ps -ef | grep '+ps,
                                        shell=True)
                )

    def test_service_port(self):
        """ Test service running by port """

        for port in self.service_port.values():
            self.assertTrue(utils.check_port("127.0.0.1", int(port)))

if __name__ == "__main__" :
    unittest.main()

