ARG IMAGE_EXT

ARG REGISTRY=ghcr.io/epics-containers
ARG RUNTIME=${REGISTRY}/epics-base${IMAGE_EXT}-runtime:7.0.9ec5
ARG DEVELOPER=${REGISTRY}/ioc-areadetector${IMAGE_EXT}-developer:3.14ec3-beta.1

##### build stage ##############################################################
FROM  ${DEVELOPER} AS developer

# initiate ioc image verson variable for manifest
ARG IOC_VERSION=unknown

ENV SOURCE_FOLDER=/epics/generic-source

# connect ioc source folder to its know location
RUN ln -s ${SOURCE_FOLDER}/ioc ${IOC}

# get the current versions of pvi and ibek
COPY requirements.txt requirements.txt
RUN uv pip install --upgrade -r requirements.txt

WORKDIR ${SOURCE_FOLDER}/ibek-support

COPY ibek-support/_ansible _ansible
ENV PATH=$PATH:${SOURCE_FOLDER}/ibek-support/_ansible

COPY ibek-support/ADUVC/ ADUVC
RUN ansible.sh ADUVC

# get the ioc source and build it
COPY ioc ${SOURCE_FOLDER}/ioc
RUN ansible.sh ioc

# generate a manifest of installed EPICS module versions and python packages
COPY scripts/generate_manifest.py /tmp/generate_manifest.py
RUN python3 /tmp/generate_manifest.py "${IOC_VERSION}"

##### runtime preparation stage ################################################
FROM developer AS runtime_prep

# get the products from the build stage and reduce to runtime assets only
RUN ibek ioc extract-runtime-assets /assets /python

##### runtime stage ############################################################
FROM ${RUNTIME} AS runtime

# get runtime assets from the preparation stage
COPY --from=runtime_prep /assets /

# install runtime system dependencies, collected from install.sh scripts
RUN ibek support apt-install-runtime-packages

# launch the startup script with stdio-expose to allow console connections
CMD ["bash", "-c", "${IOC}/start.sh"]
