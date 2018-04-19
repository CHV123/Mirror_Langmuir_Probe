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

<<<<<<< HEAD
driver.set_Temperture(50)
driver.set_Isat(2)
driver.set_Vfloating(20)
=======



driver.set_Temperature(500)
driver.set_ISat(2)
driver.set_Vfloating(0)
>>>>>>> e54e2f90958f58bfb5cd0f359cd24423de5b730d
driver.set_Resistence(100)


