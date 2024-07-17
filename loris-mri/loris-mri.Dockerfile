FROM loris-mri-deps:latest
LABEL org.childmind.image.authors="Gabriel Schubiner <gabriel.schubiner@childmind.org>"

ARG LORIS_MRI_VERSION
ENV LORIS_MRI_VERSION=${LORIS_MRI_VERSION:-26.0.0}
ENV MRI_BIN_DIR=/opt/${PROJECT_NAME}/bin/mri
ENV PROD_FILENAME=prod

### Loris-MRI ###
# https://github.com/aces/Loris-MRI/blob/main/README.md

# Create directories and download Loris-MRI.
ADD --chown=lorisadmin:lorisadmin \
    https://github.com/aces/Loris-MRI/archive/refs/tags/v${LORIS_MRI_VERSION}.tar.gz /home/lorisadmin/
RUN mkdir -p /data/${PROJECT_NAME} /opt/${PROJECT_NAME}/bin
RUN tar -xzf /home/lorisadmin/v${LORIS_MRI_VERSION}.tar.gz -C /home/lorisadmin 
RUN mv /home/lorisadmin/Loris-MRI-${LORIS_MRI_VERSION} /opt/${PROJECT_NAME}/bin/mri && \
    chown -R lorisadmin:lorisadmin /data/${PROJECT_NAME} /opt/${PROJECT_NAME}

# # Install Python dependencies.
RUN mkdir -m 770 -p ${MRI_BIN_DIR}/python_virtualenvs/loris-mri-python \
    && chown -R lorisadmin:lorisadmin ${MRI_BIN_DIR}/python_virtualenvs
RUN virtualenv ${MRI_BIN_DIR}/python_virtualenvs/loris-mri-python \
    && . ${MRI_BIN_DIR}/python_virtualenvs/loris-mri-python/bin/activate \
    && pip3 install -r ${MRI_BIN_DIR}/python/requirements.txt
# PATH=${MRI_BIN_DIR}/python_virtualenvs/loris-mri-python/bin:$PATH \

# # Make data directories.
RUN mkdir -m 2770 -p ${DATA_DIR} \
                     /data/incoming && \
    # Holds mincs that didn't match protocol
    mkdir -m 770 -p ${DATA_DIR}/trashbin \
                    # Holds tared dicom-folder
                    ${DATA_DIR}/tarchive \
                    # Holds tared hrrt-folder
                    ${DATA_DIR}/hrrtarchive \
                    # Holds jpegs generated for the MRI-browser
                    ${DATA_DIR}/pic \
                    # Holds logs from pipeline script
                    ${DATA_DIR}/logs \
                    # Holds the MINC files
                    ${DATA_DIR}/assembly \
                    # Holds the BIDS files derived from DICOMs
                    ${DATA_DIR}/assembly_bids \
                    # Contains the result of the SGE (queue)
                    ${DATA_DIR}/batch_output \
                    # Contains imported BIDS studies
                    ${DATA_DIR}/bids_imports \
                    ${MRI_BIN_DIR}/dicom-archive/.loris_mri && \
    chown -R lorisadmin:lorisadmin \
        ${DATA_DIR} \
        ${MRI_BIN_DIR}/dicom-archive/.loris_mri \
        /data/incoming

# Set up publications and issue_tracker data directory and permissions
RUN mkdir -p "${DATA_DIR}/publication_uploads/to_be_deleted/" "${DATA_DIR}/issue_tracker/" \ 
    chown -R lorisadmin:www-data "${DATA_DIR}/publication_uploads" "${DATA_DIR}/issue_tracker"

RUN sed -i \
        -e "s#%PROJECT%#${PROJECT_NAME}#g" \
        # TODO: MINC_TOOLKIT_DIR=/opt/minc/${MINC_TOOLKIT_VERSION}/ s/bin/mincheader/g
        -e "s#%MINC_TOOLKIT_DIR%#/opt/minc/${MINC_TOOLKIT_VERSION}#g" \
    ${MRI_BIN_DIR}/environment

# Set permissions for apache user and lorisadmin on
# /opt/${PROJECT_NAME}, /data/${PROJECT_NAME} and /data/incoming.
RUN chmod -R 770 /opt/${PROJECT_NAME} /data/${PROJECT_NAME} && \
    usermod -a -G www-data lorisadmin && \
    chgrp www-data -R /opt/${PROJECT_NAME} /data/${PROJECT_NAME} && \
    chmod -R g+s /data/${PROJECT_NAME}/data && \
    # Set permissions for incoming data directory
    chmod -R 770 /data/incoming && \
	chgrp www-data -R /data/incoming && \
	chmod -R g+s /data/incoming

# Install TPCCLIB for HRRT PET
RUN mkdir /usr/local/bin/tpcclib && \
    chmod 777 /usr/local/bin/tpcclib && \
    cp -r /home/lorisadmin/tpcclib/bin/* /usr/local/bin/tpcclib

# Install entrypoint script.
COPY --chown=lorisadmin:www-data --chmod=770 install-loris-mri.sh /etc/entrypoint.d/install-loris-mri.sh
# Override base image entrypoint.
COPY --chown=lorisadmin:www-data --chmod=770 loris-mri-entrypoint.sh /entrypoint.sh


###WHAT THIS SCRIPT WILL NOT DO###
#1)It doesn't set up the SGE
#2)It doesn't fetch the CIVET stuff   TODO:Get the CIVET stuff from somewhere and place it in somewhere
#3)It doesn't change the config.xml
#4)It doesn't populate the Config tables with paths etc.