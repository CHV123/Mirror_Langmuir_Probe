#!/usr/bin/env python
# -*- coding: utf-8 -*-

import time
import math
import numpy as np

from koheron import command

class PCS(object):
    def __init__(self, client):
        self.client = client
        # self.n_pts = 16384
        self.n_pts = 8192
        self.fs = 125e6 # sampling frequency (Hz)

        self.adc = np.zeros((2, self.n_pts))
        self.dac = np.zeros((2, self.n_pts))

    @command()
    def trig_pulse(self):
        pass

    @command()
    def set_ISat(self, ISat):
        pass

    @command()
    def set_Temperature(self, Temperature):
        pass


    @command()
    def set_Vfloating(self, Vfloating):
        pass


    @command()
    def set_Resistence(self, Resistence):
        pass

    @command()
    def get_Current(self):
        return self.client.recv_uint32()














