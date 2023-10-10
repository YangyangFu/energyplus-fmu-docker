import numpy as np
import pyfmi 

# Load the FMU
fmu_name = '_fmu_export_actuator.fmu'
fmu = pyfmi.load_fmu(fmu_name)

print(fmu.get_model_variables())
