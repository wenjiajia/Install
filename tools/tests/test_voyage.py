#! /usr/bin/env python
# -*- coding: utf-8 -*-
# vim: tabstop=4 shiftwidth=4 softtabstop=4

""" voyage install shell unittest """

"""
Test list:
    [x] voyage bin exist
    [x] voyage dir files exist
    [x] voyage conf correct
    [x] voyage-api service running
    [x] voyage objects API correct
    [x] voyage object API correct
    [x] voyage status API correct
    [x] voyage statu API correct
    [x] voyage strategies API correct
    [x] voyage strategy API correct
    [x] voyage update strategy API correct
"""

import os
import ConfigParser

import unittest

import utils

class TestVoyageIns(unittest.TestCase):
    """ Test voyage install shell """

    def setUp(self):
        """ Init assert cont """

        # voyage bin check list
        self.voyage_bin = ["/usr/local/bin/voyage-api",
                           "/usr/local/bin/voyage-rootwrap",
                           "/usr/local/bin/voyage-monitor",
                          ]

        # voyage dir and files check list
        self.voyage_dir_files = ["/etc/voyage/api-paste.ini",
                                 "/etc/voyage/policy.json",
                                 "/etc/voyage/voyage.conf",
                                 "/etc/voyage/logging.conf",
                                 "/etc/voyage/rootwrap.conf",
                                 "/etc/voyage/rootwrap.d",
                                 "/var/log/voyage",
                                ]

        # voyage.conf cfg check
        self.config = ConfigParser.ConfigParser()
        self.voyage_conf = "/etc/voyage/voyage.conf"
        self.sql_connection = ''.join(["mysql://root:111111@",
                                "localhost/nagios?charset=utf8"])

        # api-paste.ini cfg check
        self.api_paste = "/etc/voyage/api-paste.ini"
        self.auth_host = "127.0.0.1"
        self.admin_tenant_name = "%ADMIN_TENANT%"
        self.admin_user = "%ADMIN_USER%"
        self.admin_password = "%ADMIN_PASS%"
        self.signing_dir = "%SIGN_DIR%"

        # service deamon check
        self.port = "9257"
        self.monitor_port = "9267"

        # voyage API check
        self.tenantname = 'admin'
        self.username = 'admin'
        self.password = "123456"
        self.token = self._get_token()
        self.tenant_id = self._get_tenant()

        # voyage Object API check
        base_url = "http://localhost:9257/v1/%(tenant_id)s"
        self.objects_api = base_url + "/objects"
        self.object_api = base_url + "/objects/%(host_id)s"

        # voyage status API check
        self.status_api = base_url + "/status"
        self.statu_api = base_url + "/status/%(host_id)s"

        self.hosts = self._get_hosts()

        # voyage strategy GET API check
        self.strategies_api = base_url + '/os-strategy'
        self.strategy_api = base_url + '/os-strategy/%(strategy_id)s'

        self.strategies = self._get_strategy()
        # voyage strategy POST API check
        self.strategy_post_api = base_url + '/os-strategy/%(strategy_id)s/action'

    def test_bin(self):
        """ Test voyage bin for voyage_ins funs """
        for bin in self.voyage_bin:
            self.assertTrue(os.path.lexists(bin))

    def test_dir_files(self):
        """ Test voyage dir and files """
        for entry in self.voyage_dir_files:
            self.assertTrue(os.path.lexists(entry))

    def test_cfg(self):
        """ Test voyage cfg for voyage_cfg funs """

        self.assertTrue(os.path.lexists(self.voyage_conf))

        self.config.read(self.voyage_conf)
        # Test voyage.conf sql_connection
        self.assertNotEqual(self,
                            self.config.get("DEFAULT",
                                           "sql_connection",
                                           "Error"),
                            self.sql_connection)

        self.assertTrue(os.path.lexists(self.api_paste))

        self.config.read(self.api_paste)
        # Test api-paste
        self.assertNotEqual(self,
                            self.config.get("filter:authtoken",
                                          "auth_host",
                                          "127.0.0.1"),
                            self.auth_host)
        self.assertNotEqual(self,
                            self.config.get("filter:authtoken",
                                          "admin_tenant_name",
                                          "%ADMIN_TENANT%"),
                                self.admin_tenant_name)
        self.assertNotEqual(self,
                            self.config.get("filter:authtoken",
                                          "admin_user",
                                          "%ADMIN_USER%"),
                            self.admin_user)
        self.assertNotEqual(self,
                            self.config.get("filter:authtoken",
                                          "admin_password",
                                          "%ADMIN_PASS%"),
                            self.admin_password)
        self.assertNotEqual(self,
                            self.config.get("filter:authtoken",
                                          "signing_dir",
                                          "%SIGN_DIR%"),
                            self.signing_dir)

    def test_port(self):
        """ Test service runnint by port """

        self.assertTrue(utils.check_port("127.0.0.1", int(self.port)))
        self.assertTrue(utils.check_port("127.0.0.1", int(self.monitor_port)))

    def test_objects_api(self):
        """ Test voyage objects api """

        url = self.objects_api % {"tenant_id": self.tenant_id}
        header = {"X-Auth-Token": self.token}

        resp = utils.getUrl(url, header=header)

        self.assertTrue(resp)

        self.hosts=resp.get("hosts", [])

    def test_object_api(self):
        """ Test voyage object api """

        header = {"X-Auth-Token": self.token}

        for host in self.hosts:
            url = self.object_api % {"tenant_id": self.tenant_id,
                                     "host_id": host["host"]["id"]}

            resp = utils.getUrl(url, header=header)

            self.assertTrue(resp)

    def test_status_api(self):
        """ Test voyage status api """

        url = self.status_api % {"tenant_id": self.tenant_id}
        header = {"X-Auth-Token": self.token}

        resp = utils.getUrl(url, header=header)

        self.assertTrue(resp)

    def test_statu_api(self):
        """ Test voyage statu api """

        header = {"X-Auth-Token": self.token}

        for host in self.hosts:
            url = self.statu_api % {"tenant_id": self.tenant_id,
                                    "host_id": host["host"]["id"]}

            resp = utils.getUrl(url, header=header)

            self.assertTrue(resp)

    def test_strategies_api(self):
        """ Test voyage strategies api """

        header = {"X-Auth-Token": self.token}

        url = self.strategies_api % {'tenant_id': self.tenant_id}

        resp = utils.getUrl(url, header=header)

        self.assertTrue(resp)

    def test_strategy_api(self):
        """ Test voyage strategy api """

        header = {'X-Auth-Token': self.token}

        for strategy in self.strategies:
            url = self.strategy_api % {'tenant_id': self.tenant_id,
                                       'strategy_id': strategy['strategy_id']}

            resp = utils.getUrl(url, header=header)

            self.assertTrue(resp)

    def test_update_strategy_api(self):
        """ Test voyage update strategy api """

        header = {'X-Auth-Token': self.token}

        data = {
            "set_strategy":{
                "newid":2
            }
        }

        url = self.strategy_post_api % {'tenant_id': self.tenant_id,
                                        'strategy_id': '1'}

        resp = utils.getUrl(url, method='POST', data=data)

        self.assertTrue(resp)

    def _get_tenant(self):
        """ get Tenant id """

        url = "http://localhost:35357/v2.0/tenants"
        header = {"X-Auth-Token": self.token}

        resp = utils.getUrl(url, header=header)

        self.assertTrue(resp)

        for tenant in resp.get("tenants", []):
            if tenant["name"] == self.tenantname:
                return tenant["id"]

    def _get_token(self):
        """ get auth token """
        data = {
            "auth": {
                "tenantName": self.tenantname,
                "passwordCredentials": {
                    "username": self.username,
                    "password": self.password
                }
            }
        }

        url = "http://localhost:35357/v2.0/tokens"

        resp = utils.getUrl(url, method='POST', data=data)

        self.assertTrue(resp)

        return resp["access"]["token"]["id"]

    def _get_hosts(self):
        """ get monitor hosts """
        url = self.objects_api % {"tenant_id": self.tenant_id}
        header = {"X-Auth-Token": self.token}

        resp = utils.getUrl(url, header=header)

        return resp.get("hosts", [])

    def _get_strategy(self):
        """ get monitor strategied """

        url = self.strategies_api % {'tenant_id': self.tenant_id}
        header = {'X-Auth-Token': self.token}

        resp = utils.getUrl(url, header=header)

        return resp.get("strategies", [])

if __name__ == "__main__" :
    unittest.main()

