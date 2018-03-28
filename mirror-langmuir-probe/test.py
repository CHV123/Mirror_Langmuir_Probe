#!/usr/bin/env python
# -*- coding: utf-8 -*-

import numpy as np
import os
import time

from MLP import MLP
from koheron import connect

host = os.getenv('HOST', '198.125.182.104')
client = connect(host, name='mirror-langmuir-probe')
driver = MLP(client)

#########################################################
# Function for converting an integer to a signed binary
def int2signed(convInt):
    convInt = int(np.floor(convInt))
    if convInt < 0:
        retBin = '{:032b}'.format(convInt & 0xffffffff)
    else:
        retBin = '{:032b}'.format(convInt)

    print(convInt, retBin)
        
    return retBin
##########################################################

driver.set_voltage_1(int(int2signed(4000), 2))
driver.set_voltage_2(int(int2signed(500), 2))
driver.set_voltage_3(int(int2signed(-2000), 2))
driver.set_led(int(125e4))

print(driver.get_temperature())
print(driver.get_Isaturation())
print(driver.get_Edensity())
