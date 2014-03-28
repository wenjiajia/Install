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

        # nagios base dir
        self.base_dir = "/usr/local/nagios/"

        # bins checks
        # nagios core bin check
        self.core_bin = []
        # nagios nrpe bin check
        self.nrpe_bin = ["bin/nrpe"]
        # nagios ndo2db bin check
        self.ndo2db_bin = []
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
        self.core_cfg = []
        # nagios ndo2db cfgs check
        self.ndo2db_cfg = []
        # nagios nrpe cfgs check
        self.nrpe_cfg = [
            "etc/nrpe.cfg"
        ]

        # setting checks
        # nagios core set check
        # nagios ndo2db set check
        # nagios nrpe set check
        # nagios plugin set check

        # service checks
        # nagios initd checks
        self.initd = [
            "/etc/xinetd.d/nrpe"
        ]
        # service process check
        self.service_ps = {
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

