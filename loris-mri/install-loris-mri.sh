#!/usr/bin/env bash

set -e

export PATH=${PATH}:/usr/local/bin/tpcclib
source /opt/${PROJECT_NAME}/bin/mri/environment
MYSQL_PASSWORD=$(<${MYSQL_PASSWORD_FILE})

# Set up MRI config.
sed -e "s#DBNAME#${MYSQL_DATABASE}#g" \
    -e "s#DBUSER#${MYSQL_USER}#g" \
    -e "s#DBPASS#${MYSQL_PASSWORD}#g" \
    -e "s#DBHOST#${MYSQL_HOST}#g" \
    ${MRI_BIN_DIR}/dicom-archive/profileTemplate.pl > ${MRI_BIN_DIR}/dicom-archive/.loris_mri/${PROD_FILENAME}

chmod 640 ${MRI_BIN_DIR}/dicom-archive/.loris_mri/${PROD_FILENAME}
chgrp www-data ${MRI_BIN_DIR}/dicom-archive/.loris_mri/${PROD_FILENAME}

# Creating python database config file with database credentials
sed -e "s#DBNAME#${MYSQL_DATABASE}#g" \
    -e "s#DBUSER#${MYSQL_USER}#g" \
    -e "s#DBPASS#${MYSQL_PASSWORD}#g" \
    -e "s#DBHOST#${MYSQL_HOST}#g" \
    ${MRI_BIN_DIR}/dicom-archive/database_config_template.py > ${MRI_BIN_DIR}/dicom-archive/.loris_mri/database_config.py
chmod 640 ${MRI_BIN_DIR}/dicom-archive/.loris_mri/database_config.py
chgrp www-data ${MRI_BIN_DIR}/dicom-archive/.loris_mri/database_config.py

mysql ${MYSQL_DATABASE} -h${MYSQL_HOST} --user=${MYSQL_USER} --password="${MYSQL_PASSWORD}" -A -e "UPDATE Config SET Value='/data/${PROJECT_NAME}/data/' WHERE ConfigID=(SELECT ID FROM ConfigSettings WHERE Name='dataDirBasepath')"
mysql ${MYSQL_DATABASE} -h${MYSQL_HOST} --user=${MYSQL_USER} --password="${MYSQL_PASSWORD}" -A -e "UPDATE Config SET Value='/data/${PROJECT_NAME}/data/' WHERE ConfigID=(SELECT ID FROM ConfigSettings WHERE Name='imagePath')"
mysql ${MYSQL_DATABASE} -h${MYSQL_HOST} --user=${MYSQL_USER} --password="${MYSQL_PASSWORD}" -A -e "UPDATE Config SET Value='${PROJECT_NAME}' WHERE ConfigID=(SELECT ID FROM ConfigSettings WHERE Name='prefix')"
mysql ${MYSQL_DATABASE} -h${MYSQL_HOST} --user=${MYSQL_USER} --password="${MYSQL_PASSWORD}" -A -e "UPDATE Config SET Value='${LORIS_EMAIL}' WHERE ConfigID=(SELECT ID FROM ConfigSettings WHERE Name='mail_user')"
mysql ${MYSQL_DATABASE} -h${MYSQL_HOST} --user=${MYSQL_USER} --password="${MYSQL_PASSWORD}" -A -e "UPDATE Config SET Value='/opt/${PROJECT_NAME}/bin/mri/dicom-archive/get_dicom_info.pl' WHERE ConfigID=(SELECT ID FROM ConfigSettings WHERE Name='get_dicom_info')"
mysql ${MYSQL_DATABASE} -h${MYSQL_HOST} --user=${MYSQL_USER} --password="${MYSQL_PASSWORD}" -A -e "UPDATE Config SET Value='/data/${PROJECT_NAME}/data/tarchive/' WHERE ConfigID=(SELECT ID FROM ConfigSettings WHERE Name='tarchiveLibraryDir')"
mysql ${MYSQL_DATABASE} -h${MYSQL_HOST} --user=${MYSQL_USER} --password="${MYSQL_PASSWORD}" -A -e "UPDATE Config SET Value='/opt/${PROJECT_NAME}/bin/mri/' WHERE ConfigID=(SELECT ID FROM ConfigSettings WHERE Name='MRICodePath')"
mysql ${MYSQL_DATABASE} -h${MYSQL_HOST} --user=${MYSQL_USER} --password="${MYSQL_PASSWORD}" -A -e "UPDATE Config SET Value='${MINC_TOOLKIT_DIR}' WHERE ConfigID=(SELECT ID FROM ConfigSettings WHERE Name='MINCToolsPath')"