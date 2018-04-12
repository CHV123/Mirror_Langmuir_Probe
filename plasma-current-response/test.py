#!/usr/bin/env python
# -*- coding: utf-8 -*-

import numpy as np
import os
import time

from PCS import PCS
from koheron import connect

host = os.getenv('HOST', 'rp4')
client = connect(host, name='plasma-current-response')
driver = PCS(client)

driver.set_Temperture(50)
driver.set_Isat(2)
driver.set_Vfloating(20)
driver.set_Resistence(100)


