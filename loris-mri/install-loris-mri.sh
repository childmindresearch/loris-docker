#!/usr/bin/env bash

set -e

export PATH=${PATH}:/usr/local/bin/tpcclib
source /opt/${PROJECT_NAME}/bin/mri/environment
MYSQL_PASSWORD=$(<${MYSQL_PASSWORD_FILE})


_update_config() {
    mysql --host=${MYSQL_HOST} --user=${MYSQL_USER} --password=${MYSQL_PASSWORD} \
        -e "UPDATE Config SET Value='$2' WHERE ConfigID=(SELECT ID FROM ConfigSettings WHERE Name='$1')" ${MYSQL_DATABASE}
}


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

if [[ -n "${INSTALL_DB}" ]]; then
    _update_config 'dataDirBasepath' "${DATA_DIR}/"
    _update_config 'imagePath' "${DATA_DIR}/"
    _update_config 'prefix' "${PROJECT_NAME}"
    _update_config 'mail_user' "${LORIS_EMAIL}"
    _update_config 'get_dicom_info' "/opt/${PROJECT_NAME}/bin/mri/dicom-archive/get_dicom_info.pl"
    _update_config 'tarchiveLibraryDir' "${DATA_DIR}/tarchive/"
    _update_config 'MRICodePath' "/opt/${PROJECT_NAME}/bin/mri/"
    _update_config 'MINCToolsPath' "${MINC_TOOLKIT_DIR}"

    echo "Setting up publications data directory..."
    _update_config "publication_uploads" "${DATA_DIR}/publication_uploads/"
    _update_config "publication_deletions" "${DATA_DIR}/publication_uploads/to_be_deleted/"
    _update_config "IssueTrackerDataPath" "${DATA_DIR}/issue_tracker/"
fi