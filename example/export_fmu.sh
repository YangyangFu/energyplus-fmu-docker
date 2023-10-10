#!/bin/bash
docker run \
    --user=root \
	--detach=false \
	-e DISPLAY=${DISPLAY} \
	-v /tmp/.X11-unix:/tmp/.X11-unix\
	--rm \
	-v `pwd`:/mnt/shared \
	-i \
    -t \
	energyplus:test /bin/bash -c "cd /mnt/shared && python \${ENERGYPLUS_FMU_PATH}/Scripts/EnergyPlusToFMU.py -i /\${ENERGYPLUS_DOWNLOAD_BASENAME}/Energy+.idd -w USA_IL_Chicago-Midway.AP.725340_TMY3.epw -a 2 ./_fmu-export-actuator.idf"

rm ./idf-to-fmu-export-prep-linux util-get-address-size.exe
exit $


