#!/usr/bin/env bash

set -e

export PATH=${PATH}:/usr/local/bin/tpcclib
source /opt/${PROJECT_NAME}/bin/mri/environment

# usage: file_env VAR [DEFAULT]
#    ie: file_env 'XYZ_DB_PASSWORD' 'example'
# (will allow for "$XYZ_DB_PASSWORD_FILE" to fill in the value of
#  "$XYZ_DB_PASSWORD" from a file, especially for Docker's secrets feature)
file_env() {
	local var="$1"
	local fileVar="${var}_FILE"
	local def="${2:-}"
	if [ "${!var:-}" ] && [ "${!fileVar:-}" ]; then
		mysql_error "Both $var and $fileVar are set (but are exclusive)"
	fi
	local val="$def"
	if [ "${!var:-}" ]; then
		val="${!var}"
	elif [ "${!fileVar:-}" ]; then
		val="$(< "${!fileVar}")"
	fi
	export "$var"="$val"
	unset "$fileVar"
}

_update_config() {
    mysql --host=${MYSQL_HOST} --user=${MYSQL_USER} --password=${MYSQL_PASSWORD} \
        -e "UPDATE Config SET Value='$2' WHERE ConfigID=(SELECT ID FROM ConfigSettings WHERE Name='$1')" ${MYSQL_DATABASE}
}


# Set MYSQL_PASSWORD
file_env MYSQL_PASSWORD

# Set up MRI config
echo "Setting up MRI configuration file..."
sed -e "s#DBNAME#${MYSQL_DATABASE}#g" \
    -e "s#DBUSER#${MYSQL_USER}#g" \
    -e "s#DBPASS#${MYSQL_PASSWORD}#g" \
    -e "s#DBHOST#${MYSQL_HOST}#g" \
    ${MRI_BIN_DIR}/dicom-archive/profileTemplate.pl > ${MRI_BIN_DIR}/dicom-archive/.loris_mri/${PROD_FILENAME}

chmod 640 ${MRI_BIN_DIR}/dicom-archive/.loris_mri/${PROD_FILENAME}
chgrp www-data ${MRI_BIN_DIR}/dicom-archive/.loris_mri/${PROD_FILENAME}
echo "Done setting up MRI configuration file."

# Creating python database config file with database credentials
echo "Setting up MRI module database configuration file..."
sed -e "s#DBNAME#${MYSQL_DATABASE}#g" \
    -e "s#DBUSER#${MYSQL_USER}#g" \
    -e "s#DBPASS#${MYSQL_PASSWORD}#g" \
    -e "s#DBHOST#${MYSQL_HOST}#g" \
    ${MRI_BIN_DIR}/dicom-archive/database_config_template.py > ${MRI_BIN_DIR}/dicom-archive/.loris_mri/database_config.py
chmod 640 ${MRI_BIN_DIR}/dicom-archive/.loris_mri/database_config.py
chgrp www-data ${MRI_BIN_DIR}/dicom-archive/.loris_mri/database_config.py
echo "Done setting up MRI module database configuration file."

if [[ "${INSTALL_DB}" == "True" ]]; then
    echo "Setting up MRI database config..."
    _update_config 'dataDirBasepath' "${DATA_DIR}/"
    _update_config 'imagePath' "${DATA_DIR}/"
    _update_config 'prefix' "${PROJECT_NAME}"
    _update_config 'mail_user' "${LORIS_EMAIL}"
    _update_config 'get_dicom_info' "/opt/${PROJECT_NAME}/bin/mri/dicom-archive/get_dicom_info.pl"
    _update_config 'tarchiveLibraryDir' "${DATA_DIR}/tarchive/"
    _update_config 'MRICodePath' "/opt/${PROJECT_NAME}/bin/mri/"
    _update_config 'MINCToolsPath' "${MINC_TOOLKIT_DIR}"
    echo "Done setting up MRI database config."

    echo "Setting up publications data directory..."
    _update_config "publication_uploads" "${DATA_DIR}/publication_uploads/"
    _update_config "publication_deletions" "${DATA_DIR}/publication_uploads/to_be_deleted/"
    _update_config "IssueTrackerDataPath" "${DATA_DIR}/issue_tracker/"
    echo "Done setting up publications data directory."
fi