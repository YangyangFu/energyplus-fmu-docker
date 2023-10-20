import numpy as np
import pyfmi

# load fmu
fmu = pyfmi.load_fmu('_fmu_export_actuator.fmu')

# get model variables
model_variables = fmu.get_model_variables()

