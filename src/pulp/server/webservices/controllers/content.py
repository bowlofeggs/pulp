# -*- coding: utf-8 -*-
#
# Copyright © 2010 Red Hat, Inc.
#
# This software is licensed to you under the GNU General Public
# License as published by the Free Software Foundation; either version
# 2 of the License (GPLv2) or (at your option) any later version.
# There is NO WARRANTY for this software, express or implied,
# including the implied warranties of MERCHANTABILITY,
# NON-INFRINGEMENT, or FITNESS FOR A PARTICULAR PURPOSE. You should
# have received a copy of GPLv2 along with this software; if not, see
# http://www.gnu.org/licenses/old-licenses/gpl-2.0.txt.

import logging

import web

from pulp.server.api.file import FileApi
from pulp.server.auth.authorization import READ, DELETE
from pulp.server.webservices.controllers.base import JSONController
from pulp.server.webservices.controllers.decorators import (
    auth_required, error_handler)

# globals ---------------------------------------------------------------------

api = FileApi()
log = logging.getLogger('pulp')

class File(JSONController):

    @error_handler
    @auth_required(READ)
    def GET(self, id):
        """
        [[wiki]]
        title: Get File info
        description: lookup file for a given id
        method: PUT
        path: /content/file/<id>/
        permission: READ
        success response: 200 OK
        failure response: 400 Bad Request when trying to change the id
        return: a File object
        """
        return self.ok(api.file(id))

    @error_handler
    @auth_required(DELETE)
    def DELETE(self, id):
        """
        Delete an file
        @param id: file id to delete
        @return: True on successful deletion of file
        """
        api.delete(id=id)
        return self.ok(True)

# web.py application ----------------------------------------------------------

URLS = (
    '/file/([^/]+)/$', 'File',
)

application = web.application(URLS, globals())
