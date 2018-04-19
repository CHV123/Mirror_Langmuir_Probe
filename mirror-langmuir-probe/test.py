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

driver.set_period(1250)
driver.set_acquisition_length(int(250))

driver.set_trigger(int(0b11111111111111111111111111111111))
driver.set_trigger(0)

while True:
    try:
        time.sleep(0.2)
        samples = driver.get_buffer_length()
        if samples == 0:
            break
        print(samples)
    except KeyboardInterrupt:
        break

dataArray = driver.get_MLP_data()
print(len(dataArray))

saveStr = "MLP_test_data"
print(saveStr)
np.save(saveStr, dataArray)
