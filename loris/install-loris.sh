#!/usr/bin/env bash

set -e

# Set directory environment variables.
BASE_PATH="/var/www/loris/"
DATA_DIR="/data/${PROJECT_NAME}/data/"

_load_secrets() {
    MYSQL_PASSWORD=$(<${MYSQL_PASSWORD_FILE})
    LORIS_ADMIN_PASSWORD=$(<${LORIS_ADMIN_PASSWORD_FILE})
}

_update_config() {
    mysql --host=${MYSQL_HOST} --user=${MYSQL_USER} --password=${MYSQL_PASSWORD} \
        -e "UPDATE Config SET Value='$2' WHERE ConfigID=(SELECT ID FROM ConfigSettings WHERE Name='$1')" ${MYSQL_DATABASE}
}

_update_admin_pass() {
    local LORIS_ADMIN_PASSWORD_HASH=$(
        echo -n $2 | php -r 'echo password_hash(file_get_contents("php://stdin"), PASSWORD_DEFAULT);'
    )
    mysql --host=${MYSQL_HOST} --user=${MYSQL_USER} --password=${MYSQL_PASSWORD} \
        -e "UPDATE users SET UserID='${1}', Password_hash='${LORIS_ADMIN_PASSWORD_HASH}', Email='${LORIS_EMAIL}', Active='Y' WHERE ID=1" ${MYSQL_DATABASE}
}

_update_admin_site() {
    mysql --host=${MYSQL_HOST} --user=${MYSQL_USER} --password=${MYSQL_PASSWORD} \
        -e "UPDATE user_psc_rel SET CenterID=(SELECT ID FROM psc WHERE Name='${SITE_NAME}') WHERE ID=1" ${MYSQL_DATABASE}
}

#INSERT INTO psc (Name, Alias, MRI_alias, Study_site) VALUES ('${SITE_NAME}','${SITE_ALIAS}','${MRI_ALIAS}','${STUDY_SITE_YN}');
_initialize_study_db() {
    mysql --host=${MYSQL_HOST} --user=${MYSQL_USER} --password=${MYSQL_PASSWORD} ${MYSQL_DATABASE} <<EOF
UPDATE psc SET Name='${SITE_NAME}', Alias='${SITE_ALIAS}', MRI_alias='${MRI_ALIAS}', Study_site='${STUDY_SITE_YN}' WHERE CenterID=1;
INSERT INTO Visit_Windows (Visit_label,  WindowMinDays, WindowMaxDays, OptimumMinDays, OptimumMaxDays, WindowMidpointDays) VALUES ('${VISIT_LABEL}', ${WINDOW_MIN_DAYS}, ${WINDOW_MAX_DAYS}, ${OPTIMUM_MIN_DAYS}, ${OPTIMUM_MAX_DAYS}, ${WINDOW_MIDPOINT_DAYS});
INSERT INTO visit (VisitName, VisitLabel) VALUES ('${VISIT_NAME}', '${VISIT_LABEL}');
EOF
}

_install_instruments() {
    cd /var/www/loris/tools/
    for instrument_file in /etc/loris_instruments/*.linst; do
        local instrument_filename=$(basename ${instrument_file})
        local instrument=${instrument_filename%.linst}
        if [[ -f "/var/www/loris/project/instruments/${instrument_filename}" ]]; then
            echo "Skipping instrument ${instrument_file} as it already exists."
            continue
        fi
        echo "Installing instrument ${instrument}..."
        cp ${instrument_file} /var/www/loris/project/instruments/
        echo "Generating ${instrument} SQL tables and testNames..."
        php generate_tables_sql_and_testNames.php < ${instrument_file}
        echo "Installing ${instrument} in database..."
        mysql --host=${MYSQL_HOST} --user=${MYSQL_USER} --password=${MYSQL_PASSWORD} ${MYSQL_DATABASE} < /var/www/loris/project/tables_sql/${instrument}.sql
        echo "Done installing ${instrument}."
        chown -R lorisadmin:www-data /var/www/loris/project/instruments/ /var/www/loris/project/tables_sql/
    done
    cd -
}

install_loris() {
    _load_secrets
    echo "Loris configuration does not exist. Installing configuration with values:"
    echo "MYSQL_HOST: ${MYSQL_HOST}"
    echo "MYSQL_USER: ${MYSQL_USER}"
    echo "MYSQL_DATABASE: ${MYSQL_DATABASE}"
    echo "LORIS_ADMIN_USER: ${LORIS_ADMIN_USER}"
    echo "LORIS_ADMIN_PASSWORD: ${LORIS_ADMIN_PASSWORD}"

    # Update the Loris admin user password in database.
    _update_admin_pass $LORIS_ADMIN_USER $LORIS_ADMIN_PASSWORD

    # Update the configuration paths and host.
    _update_config "base" "${BASE_PATH}"
    _update_config "DownloadPath" "${BASE_PATH}"
    _update_config "url" "http://${LORIS_HOST}:${LORIS_PORT}"
    _update_config "host" "${LORIS_HOST}"
    _update_config "data" "${DATA_DIR}"
    _update_config "imagePath" "${DATA_DIR}"
    _update_config "MRICodePath" "${DATA_DIR}"
    _update_config "JWTKey" $(cat /dev/urandom | LC_ALL=C tr -dc 'a-zA-Z0-9!\$^@#%&*()' | fold -w 32 | head -n 1)

    # Copy base configuration.
    cp /var/www/loris/docs/config/config.xml /var/www/loris/project/config.xml

    # Replace placeholders with environment variables.
    sed -i \
        -e "s/%HOSTNAME%/${MYSQL_HOST}/g" \
        -e "s/%USERNAME%/${MYSQL_USER}/g" \
        -e "s/%PASSWORD%/${MYSQL_PASSWORD}/g" \
        -e "s/%DATABASE%/${MYSQL_DATABASE}/g" \
        /var/www/loris/project/config.xml
    chown lorisadmin:www-data /var/www/loris/project/config.xml
    chmod 660 /var/www/loris/project/config.xml

    _initialize_study_db
}

# Install Loris configuration if DEBUG_CONTAINER is not set.
echo "Configuring Loris..."
if [ ! -f /var/www/loris/projects/config.xml ] && [[ -z "${DEBUG_CONTAINER}" ]]; then
    echo "Loris configuration does not exist. Installing configuration."
    install_loris
else
    echo "Skipping Loris configuration installation."
fi

if [[ -d /etc/loris_instruments ]]; then
    echo "Installing instruments..."
    _install_instruments
else
    echo "Instruments directory does not exist. Skipping instrument installation."
fi
