#!/usr/bin/env bash

set -e

export PATH=${PATH}:/usr/local/bin/tpcclib
source /opt/${PROJECT_NAME}/bin/mri/environment

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

# mysql $mysqldb -h$mysqlhost --user=$mysqluser --password="$mysqlpass" -A -e "UPDATE Config SET Value='/data/$PROJ/data/' WHERE ConfigID=(SELECT ID FROM ConfigSettings WHERE Name='dataDirBasepath')"
# mysql $mysqldb -h$mysqlhost --user=$mysqluser --password="$mysqlpass" -A -e "UPDATE Config SET Value='/data/$PROJ/data/' WHERE ConfigID=(SELECT ID FROM ConfigSettings WHERE Name='imagePath')"
# mysql $mysqldb -h$mysqlhost --user=$mysqluser --password="$mysqlpass" -A -e "UPDATE Config SET Value='$PROJ' WHERE ConfigID=(SELECT ID FROM ConfigSettings WHERE Name='prefix')"
# mysql $mysqldb -h$mysqlhost --user=$mysqluser --password="$mysqlpass" -A -e "UPDATE Config SET Value='$email' WHERE ConfigID=(SELECT ID FROM ConfigSettings WHERE Name='mail_user')"
# mysql $mysqldb -h$mysqlhost --user=$mysqluser --password="$mysqlpass" -A -e "UPDATE Config SET Value='/opt/$PROJ/bin/mri/dicom-archive/get_dicom_info.pl' WHERE ConfigID=(SELECT ID FROM ConfigSettings WHERE Name='get_dicom_info')"
# mysql $mysqldb -h$mysqlhost --user=$mysqluser --password="$mysqlpass" -A -e "UPDATE Config SET Value='/data/$PROJ/data/tarchive/' WHERE ConfigID=(SELECT ID FROM ConfigSettings WHERE Name='tarchiveLibraryDir')"
# mysql $mysqldb -h$mysqlhost --user=$mysqluser --password="$mysqlpass" -A -e "UPDATE Config SET Value='/opt/$PROJ/bin/mri/' WHERE ConfigID=(SELECT ID FROM ConfigSettings WHERE Name='MRICodePath')"
# mysql $mysqldb -h$mysqlhost --user=$mysqluser --password="$mysqlpass" -A -e "UPDATE Config SET Value='$MINC_TOOLKIT_DIR' WHERE ConfigID=(SELECT ID FROM ConfigSettings WHERE Name='MINCToolsPath')"