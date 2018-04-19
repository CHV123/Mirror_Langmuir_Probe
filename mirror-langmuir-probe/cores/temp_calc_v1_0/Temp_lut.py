# Python script to generate the saturation current look up table

import numpy as np
import matplotlib.pyplot as plt

dataArray = []

xVal = np.linspace(-1, 15, num=2**14)

def lutFunction(x):
    ln = np.log(x + 1)
    func = 1/(ln)
    # if x >= -8 and x < -1:
    #     func = func*(2**13)
    # elif x >= -1 and x <= 1:
    #     func = func*(2**2)
    # elif x > 1 and x <=8:
    #     func = func*(2**14)

    return int(round(func))

for i in range(len(xVal)):
    dataArray.append(round(lutFunction(xVal[i])))

#dataArray = np.array(dataArray)

plt.plot(xVal, dataArray)
plt.show()

# with open("iSat_lut.coe", "w") as lut_file:
#     lut_file.write("memory_initialization_radix=10;\n")
#     lut_file.write("memory_initialization_vector=")
#     for val in dataArray:
#         lut_file.write("%i " % val) 
