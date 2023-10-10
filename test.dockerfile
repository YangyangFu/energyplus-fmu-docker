FROM yangyangfu/energyplus:v22.2.0 

USER root

# add a developer user
# create user and render using X11 forwarding 
RUN export uid=1000 gid=1000 && \
    mkdir -p /home/developer && \
    mkdir -p /etc/sudoers.d && \
    echo "developer:x:${uid}:${gid}:Developer,,,:/home/developer:/bin/bash" >> /etc/passwd && \
    echo "developer:x:${uid}:" >> /etc/group && \
    echo "developer ALL=(ALL) NOPASSWD: ALL" > /etc/sudoers.d/developer && \
    chmod 0440 /etc/sudoers.d/developer && \
    chown ${uid}:${gid} -R /home/developer && \
    mkdir -m 1777 /tmp/.X11-unix

ENV HOME /home/developer

# install energyplus-fmu
RUN apt-get update \
    && apt-get install -y g++ unzip \
    && rm -rf /var/lib/apt/lists/*
# download energyplus-fmu
RUN mkdir -p /home/developer/energyplus-fmu \
    && cd /home/developer/energyplus-fmu \
    && wget https://github.com/lbl-srg/EnergyPlusToFMU/releases/download/v3.1.0/EnergyPlusToFMU-v3.1.0.zip \
    && unzip EnergyPlusToFMU-v3.1.0.zip \
    && rm EnergyPlusToFMU-v3.1.0.zip 

ENV ENERGYPLUS_FMU_PATH /home/developer/energyplus-fmu

USER developer
WORKDIR /home/developer

# activate conda environment
RUN conda init bash && \
    . ~/.bashrc
SHELL ["conda", "run", "-n", "base", "/bin/bash", "-c"]
