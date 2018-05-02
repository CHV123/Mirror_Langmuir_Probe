#!/usr/bin/env python
# -*- coding: utf-8 -*-

import time
import math
import numpy as np

from koheron import command

class MLP(object):
    def __init__(self, client):
        self.client = client
        # self.n_pts = 16384
        self.n_pts = 8192
        self.fs = 125e6 # sampling frequency (Hz)

        self.adc = np.zeros((2, self.n_pts))
        self.dac = np.zeros((2, self.n_pts))


    @command()
    def set_trigger(self, trigger):
        pass
    
    @command()
    def set_led(self, led):
        pass
    
    @command()
    def set_period(self, period):
        pass

    @command()
    def set_acquisition_length(self, period):
        pass
    
    @command()
    def get_Temperature(self):
        return self.client.recv_uint32()

    @command()
    def get_Isaturation(self):
        return self.client.recv_uint32()

    @command()
    def get_vFloat(self):
        return self.client.recv_uint32()

    @command()
    def get_Coefficients(self):
        return self.client.recv_uint32()    
    

    # def set_dac(self):
    #     @command()
    #     def set_dac_data(self, data):
    #         pass
    #     dac_data_1 = np.uint32(np.mod(np.floor(8192 * self.dac[0, :]) + 8192, 16384) + 8192)
    #     dac_data_2 = np.uint32(np.mod(np.floor(8192 * self.dac[1, :]) + 8192, 16384) + 8192)
    #     set_dac_data(self, dac_data_1 + 65536 * dac_data_2)

    # @command()
    # def get_fifo_length(self):
    #     return self.client.recv_uint32()

    @command()
    def get_MLP_data(self):
        return self.client.recv_vector(dtype='uint32')

    @command()
    def get_buffer_length(self):
        return self.client.recv_uint32() 

    # @command()
    # def reset_fifo(self):
    #     pass

