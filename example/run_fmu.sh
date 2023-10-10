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
    energyplus:test /bin/bash -c "cd /mnt/shared && python run_fmu.py"
exit &