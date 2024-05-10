FROM loris:latest
LABEL org.childmind.image.authors="Gabriel Schubiner <gabriel.schubiner@childmind.org>"

ARG LORIS_MRI_VERSION=24.1.16
ARG MINC_TOOLKIT_VERSION=1.9.18
ARG MINC_TOOLKIT_RELEASE_VERSION=1.9.18-20220625-Ubuntu_20.04
ARG MINC_TOOLKIT_TESTSUITE_VERSION=0.1.3-20131212
ARG BEAST_LIBRARY_VERSION=1.1.0-20121212
ARG BIC_MNI_MODELS_VERSION=0.1.1-20120421
ARG MRI_BIN_DIR=/opt/${PROJECT_NAME}/bin/mri
ARG PROD_FILENAME=prod

# Update and install dependencies.
RUN DEBIAN_FRONTEND=noninteractive \
    apt-get -qqq update && \
    apt-get -y install \
        cpanminus \
        dcmtk \
        gdebi-core \
        imagemagick \
        libc6 \
        libgl1-mesa-glx \
        libglu1-mesa \
        libstdc++6 \
        octave \
        perl \
        pkg-config \
        python3-dev \
        python3-pip \
        virtualenv \
    && rm -rf /var/lib/apt/lists/*

# Install Perl dependencies.
# Copy patched version of Digest::BLAKE2 because CPAN version fails to build.
# Reference: https://github.com/Raptor3um/raptoreum/issues/48#issuecomment-969125200
COPY deps/Digest-BLAKE2-0.02.tar.gz /root/
RUN cpanm /root/Digest-BLAKE2-0.02.tar.gz
RUN cpanm \
        Archive::Extract \
        Archive::Zip \
        DateTime \
        DBI \
        DBD::mysql \
        File::Type \
        Getopt::Tabular \
        JSON \
        Math::Round \
        Moose \
        MooseX::Privacy \
        Path::Class \
        Pod::Perldoc \
        Pod::Markdown \
        Pod::Usage \
        String::ShellQuote \
        Time::JulianDay \
        TryCatch \
        Throwable

### Loris-MRI ###
# https://github.com/aces/Loris-MRI/blob/main/README.md

# Download MINC Toolkit and dependencies.
ADD --chown=lorisadmin:lorisadmin https://packages.bic.mni.mcgill.ca/minc-toolkit/Debian/minc-toolkit-${MINC_TOOLKIT_RELEASE_VERSION}-x86_64.deb /home/lorisadmin/
ADD --chown=lorisadmin:lorisadmin https://packages.bic.mni.mcgill.ca/minc-toolkit/Debian/minc-toolkit-testsuite-${MINC_TOOLKIT_TESTSUITE_VERSION}.deb /home/lorisadmin/
ADD --chown=lorisadmin:lorisadmin http://packages.bic.mni.mcgill.ca/minc-toolkit/Debian/beast-library-${BEAST_LIBRARY_VERSION}.deb /home/lorisadmin/
ADD --chown=lorisadmin:lorisadmin http://packages.bic.mni.mcgill.ca/minc-toolkit/Debian/bic-mni-models-${BIC_MNI_MODELS_VERSION}.deb /home/lorisadmin/

# Install MINC Toolkit and dependencies.
RUN dpkg -i /home/lorisadmin/minc-toolkit-${MINC_TOOLKIT_RELEASE_VERSION}-x86_64.deb \
            /home/lorisadmin/minc-toolkit-testsuite-${MINC_TOOLKIT_TESTSUITE_VERSION}.deb \
            /home/lorisadmin/bic-mni-models-${BIC_MNI_MODELS_VERSION}.deb \
            /home/lorisadmin/beast-library-${BEAST_LIBRARY_VERSION}.deb \
    && apt-get -f install -y
RUN gdebi /home/lorisadmin/minc-toolkit-${MINC_TOOLKIT_RELEASE_VERSION}-x86_64.deb
RUN gdebi /home/lorisadmin/minc-toolkit-testsuite-${MINC_TOOLKIT_TESTSUITE_VERSION}.deb 
RUN gdebi /home/lorisadmin/bic-mni-models-${BIC_MNI_MODELS_VERSION}.deb
RUN gdebi /home/lorisadmin/beast-library-${BEAST_LIBRARY_VERSION}.deb
RUN apt-get autoclean && rm -rf /var/lib/apt/lists/*

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
RUN mkdir -m 2770 -p /data/${PROJECT_NAME}/data/ \
                     /data/incoming && \
    # Holds mincs that didn't match protocol
    mkdir -m 770 -p /data/${PROJECT_NAME}/data/trashbin \
                    # Holds tared dicom-folder
                    /data/${PROJECT_NAME}/data/tarchive \
                    # Holds tared hrrt-folder
                    /data/${PROJECT_NAME}/data/hrrtarchive \
                    # Holds jpegs generated for the MRI-browser
                    /data/${PROJECT_NAME}/data/pic \
                    # Holds logs from pipeline script
                    /data/${PROJECT_NAME}/data/logs \
                    # Holds the MINC files
                    /data/${PROJECT_NAME}/data/assembly \
                    # Holds the BIDS files derived from DICOMs
                    /data/${PROJECT_NAME}/data/assembly_bids \
                    # Contains the result of the SGE (queue)
                    /data/${PROJECT_NAME}/data/batch_output \
                    # Contains imported BIDS studies
                    /data/${PROJECT_NAME}/data/bids_imports \
                    ${MRI_BIN_DIR}/dicom-archive/.loris_mri && \
    chown -R lorisadmin:lorisadmin \
        /data/${PROJECT_NAME}/data \
        ${MRI_BIN_DIR}/dicom-archive/.loris_mri \
        /data/incoming

RUN sed -i \
        -e "s#%PROJECT%#${PROJECT_NAME}#g" \
        # TODO: MINC_TOOLKIT_DIR=/opt/minc/${MINC_TOOLKIT_VERSION}/ s/bin/mincheader/g
        -e "s#%MINC_TOOLKIT_DIR%#/opt/minc/${MINC_TOOLKIT_VERSION}/#g" \
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

# Add TPCCLIB from local repository because download is rate-limited and takes a long time.
# ADD https://seafile.utu.fi/d/15843078fb/files/?p=%2Ftpcclib-0.8.0-Linux-x86_64.tar.gz&dl=1 /home/lorisadmin/
ADD deps/tpcclib-0.8.0-Linux-x86_64.tar.gz /home/lorisadmin/tpcclib

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

#### TODO: Move to entrypoint script.
# Set up MRI config.
# RUN sed \
#         -e "s#DBNAME#$mysqldb#g" \
#         -e "s#DBUSER#$mysqluser#g" \
#         -e "s#DBPASS#$mysqlpass#g" \
#         -e "s#DBHOST#$mysqlhost#g" \
#     ${MRI_BIN_DIR}/dicom-archive/profileTemplate.pl > ${MRI_BIN_DIR}/dicom-archive/.loris_mri/${PROD_FILENAME} && \
#     chmod 640 ${MRI_BIN_DIR}/dicom-archive/.loris_mri/${PROD_FILENAME} && \
#     chgrp www-data ${MRI_BIN_DIR}/dicom-archive/.loris_mri/${PROD_FILENAME}

# Creating python database config file with database credentials
# RUN sed \
#         -e "s#DBNAME#$mysqldb#g" \
#         -e "s#DBUSER#$mysqluser#g" \
#         -e "s#DBPASS#$mysqlpass#g" \
#         -e "s#DBHOST#$mysqlhost#g" \
#     ${MRI_BIN_DIR}/dicom-archive/database_config_template.py > ${MRI_BIN_DIR}/dicom-archive/.loris_mri/database_config.py && \
#     chmod 640 ${MRI_BIN_DIR}/dicom-archive/.loris_mri/database_config.py && \
#     chgrp www-data ${MRI_BIN_DIR}/dicom-archive/.loris_mri/database_config.py

# # mysql $mysqldb -h$mysqlhost --user=$mysqluser --password="$mysqlpass" -A -e "UPDATE Config SET Value='/data/$PROJ/data/' WHERE ConfigID=(SELECT ID FROM ConfigSettings WHERE Name='dataDirBasepath')"
# # mysql $mysqldb -h$mysqlhost --user=$mysqluser --password="$mysqlpass" -A -e "UPDATE Config SET Value='/data/$PROJ/data/' WHERE ConfigID=(SELECT ID FROM ConfigSettings WHERE Name='imagePath')"
# # mysql $mysqldb -h$mysqlhost --user=$mysqluser --password="$mysqlpass" -A -e "UPDATE Config SET Value='$PROJ' WHERE ConfigID=(SELECT ID FROM ConfigSettings WHERE Name='prefix')"
# # mysql $mysqldb -h$mysqlhost --user=$mysqluser --password="$mysqlpass" -A -e "UPDATE Config SET Value='$email' WHERE ConfigID=(SELECT ID FROM ConfigSettings WHERE Name='mail_user')"
# # mysql $mysqldb -h$mysqlhost --user=$mysqluser --password="$mysqlpass" -A -e "UPDATE Config SET Value='/opt/$PROJ/bin/mri/dicom-archive/get_dicom_info.pl' WHERE ConfigID=(SELECT ID FROM ConfigSettings WHERE Name='get_dicom_info')"
# # mysql $mysqldb -h$mysqlhost --user=$mysqluser --password="$mysqlpass" -A -e "UPDATE Config SET Value='/data/$PROJ/data/tarchive/' WHERE ConfigID=(SELECT ID FROM ConfigSettings WHERE Name='tarchiveLibraryDir')"
# # mysql $mysqldb -h$mysqlhost --user=$mysqluser --password="$mysqlpass" -A -e "UPDATE Config SET Value='/opt/$PROJ/bin/mri/' WHERE ConfigID=(SELECT ID FROM ConfigSettings WHERE Name='MRICodePath')"
# # mysql $mysqldb -h$mysqlhost --user=$mysqluser --password="$mysqlpass" -A -e "UPDATE Config SET Value='$MINC_TOOLKIT_DIR' WHERE ConfigID=(SELECT ID FROM ConfigSettings WHERE Name='MINCToolsPath')"

# # export PATH=${PATH}:/usr/local/bin/tpcclib
# # source /opt/$projectname/bin/mri/environment
# # RUN . /opt/minc/${MINC_TOOLKIT_VERSION}