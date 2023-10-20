
# Keep ARG outside of build images so can access globally
# This is not ideal. The tarballs are not named nicely and EnergyPlus versioning is strange
ARG ENERGYPLUS_VERSION
ARG ENERGYPLUS_SHA
ARG ENERGYPLUS_INSTALL_VERSION
ARG ENERGYPLUS_TAG
ARG UBUNTU_BASE=22.04

FROM ubuntu:$UBUNTU_BASE AS base

LABEL author="Yangyang Fu"

ARG ENERGYPLUS_VERSION
ARG ENERGYPLUS_SHA
ARG ENERGYPLUS_INSTALL_VERSION
ARG ENERGYPLUS_TAG
ARG UBUNTU_BASE

ENV ENERGYPLUS_VERSION=$ENERGYPLUS_VERSION
ENV ENERGYPLUS_TAG=$ENERGYPLUS_TAG
ENV ENERGYPLUS_SHA=$ENERGYPLUS_SHA
ENV UBUNTU_BASE=$UBUNTU_BASE

# This should be x.y.z, but EnergyPlus convention is x-y-z
ENV ENERGYPLUS_INSTALL_VERSION=$ENERGYPLUS_INSTALL_VERSION

# Downloading from GitHub
# e.g. https://github.com/NREL/EnergyPlus/releases/download/v22.1.0/EnergyPlus-22.1.0-ed759b17ee-Linux-Ubuntu20.04-x86_64.tar.gz
ENV ENERGYPLUS_DOWNLOAD_BASE_URL https://github.com/NREL/EnergyPlus/releases/download/$ENERGYPLUS_TAG
ENV ENERGYPLUS_DOWNLOAD_BASENAME EnergyPlus-$ENERGYPLUS_VERSION-$ENERGYPLUS_SHA-Linux-Ubuntu$UBUNTU_BASE-x86_64
ENV ENERGYPLUS_DOWNLOAD_FILENAME $ENERGYPLUS_DOWNLOAD_BASENAME.tar.gz
ENV ENERGYPLUS_DOWNLOAD_URL $ENERGYPLUS_DOWNLOAD_BASE_URL/$ENERGYPLUS_DOWNLOAD_FILENAME

ENV SIMDATA_DIR=/var/simdata

# Download
RUN apt-get update \
    && apt-get install -y ca-certificates curl libx11-6 libexpat1 python3 python3-pip $(["$UBUNTU_BASE" = "22.04"] && echo -n "libmd0") \
    && rm -rf /var/lib/apt/lists/* \
    && curl -SLO $ENERGYPLUS_DOWNLOAD_URL

# Unzip
RUN tar -zxvf $ENERGYPLUS_DOWNLOAD_FILENAME \
    && cd $ENERGYPLUS_DOWNLOAD_BASENAME \
    && chmod +x energyplus \
    && ln -s energyplus EnergyPlus

RUN mkdir -p $SIMDATA_DIR/energyplus \
    && cd $ENERGYPLUS_DOWNLOAD_BASENAME \
    && cp ExampleFiles/1ZoneUncontrolled.idf $SIMDATA_DIR \
    && cp ExampleFiles/PythonPluginCustomOutputVariable.idf $SIMDATA_DIR \
    && cp ExampleFiles/PythonPluginCustomOutputVariable.py $SIMDATA_DIR

# Remove datasets to slim down the EnergyPlus folder
RUN rm ${ENERGYPLUS_DOWNLOAD_BASENAME}.tar.gz \
    && cd $ENERGYPLUS_DOWNLOAD_BASENAME \
    && rm -rf DataSets Documentation ExampleFiles WeatherData MacroDataSets PostProcess/convertESOMTRpgm \
    PostProcess/EP-Compare PreProcess/FMUParser PreProcess/ParametricPreProcessor PreProcess/IDFVersionUpdater

# Conditional copy depending on UBUNTU_BASE
FROM ubuntu:18.04 as build_18.04
ONBUILD COPY --from=base \
    /lib/x86_64-linux-gnu/libbsd.so* \
    /lib/x86_64-linux-gnu/libexpat.so* \
    /lib/x86_64-linux-gnu/

FROM ubuntu:20.04 as build_20.04
ONBUILD COPY --from=base \
    /usr/lib/x86_64-linux-gnu/libbsd.so* \
    /usr/lib/x86_64-linux-gnu/libexpat.so* \
    /usr/lib/x86_64-linux-gnu/

FROM ubuntu:22.04 as build_22.04
ONBUILD COPY --from=base \
    /usr/lib/x86_64-linux-gnu/libbsd.so* \
    /usr/lib/x86_64-linux-gnu/libexpat.so* \
    /usr/lib/x86_64-linux-gnu/libmd.so* \
    /usr/lib/x86_64-linux-gnu/

# Use Multi-stage build to produce a smaller final image
FROM build_${UBUNTU_BASE} AS runtime

ARG ENERGYPLUS_VERSION
ARG ENERGYPLUS_SHA
ARG UBUNTU_BASE

ENV ENERGYPLUS_VERSION=$ENERGYPLUS_VERSION
ENV ENERGYPLUS_SHA=$ENERGYPLUS_SHA
ENV ENERGYPLUS_DOWNLOAD_BASENAME EnergyPlus-$ENERGYPLUS_VERSION-$ENERGYPLUS_SHA-Linux-Ubuntu$UBUNTU_BASE-x86_64
ENV SIMDATA_DIR=/var/simdata

COPY --from=base $ENERGYPLUS_DOWNLOAD_BASENAME $ENERGYPLUS_DOWNLOAD_BASENAME
COPY --from=base $SIMDATA_DIR $SIMDATA_DIR

# Copy shared libraries required to run energyplus
COPY --from=base \
    /usr/lib/x86_64-linux-gnu/libX11.so* \
    /usr/lib/x86_64-linux-gnu/libxcb.so* \
    /usr/lib/x86_64-linux-gnu/libXau.so* \
    /usr/lib/x86_64-linux-gnu/libXdmcp.so* \
    /usr/lib/x86_64-linux-gnu/libgomp.so* \
    /usr/lib/x86_64-linux-gnu/

# Add energyplus to PATH so can run "energyplus" in any directory
ENV PATH="/${ENERGYPLUS_DOWNLOAD_BASENAME}:${PATH}"

# Add Conda

## add a conda for python 3 environment
# Install miniconda - this is from 
# https://github.com/ContinuumIO/docker-images/blob/master/miniconda3/debian/Dockerfile
# =================================
# hadolint ignore=DL3008
 RUN apt-get update -q && \
    apt-get install -q -y --no-install-recommends \
    bzip2 \
    ca-certificates \
    git \
    libglib2.0-0 \
    libsm6 \
    libxext6 \
    libxrender1 \
    mercurial \
    subversion \
    wget \
    xterm \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

ENV PATH /opt/conda/bin:$PATH

# Leave these args here to better use the Docker build cache
ARG CONDA_VERSION=py311_23.5.2-0

RUN set -x && \
    MINICONDA_URL="https://repo.anaconda.com/miniconda/Miniconda3-${CONDA_VERSION}-Linux-x86_64.sh"; \
    SHA256SUM="634d76df5e489c44ade4085552b97bebc786d49245ed1a830022b0b406de5817"; \
    wget "${MINICONDA_URL}" -O miniconda.sh -q && \
    echo "${SHA256SUM} miniconda.sh" > shasum && \
    if [ "${CONDA_VERSION}" != "latest" ]; then sha256sum --check --status shasum; fi && \
    mkdir -p /opt && \
    bash miniconda.sh -b -p /opt/conda && \
    rm miniconda.sh shasum && \
    ln -s /opt/conda/etc/profile.d/conda.sh /etc/profile.d/conda.sh && \
    echo ". /opt/conda/etc/profile.d/conda.sh" >> ~/.bashrc && \
    echo "conda activate base" >> ~/.bashrc && \
    find /opt/conda/ -follow -type f -name '*.a' -delete && \
    find /opt/conda/ -follow -type f -name '*.js.map' -delete && \
    /opt/conda/bin/conda clean -afy

# create a conda environment install pyfmi for load fmu 
RUN conda update conda && \
    conda config --add channels conda-forge && \
    conda install pyfmi pandas matplotlib ipykernel && \
    conda clean -afy

# activate conda environment
RUN conda init bash && \
    . ~/.bashrc
SHELL ["conda", "run", "-n", "base", "/bin/bash", "-c"]
