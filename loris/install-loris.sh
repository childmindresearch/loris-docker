#!/usr/bin/env bash

set -e

CONFIG_XML="${BASE_PATH}/project/config.xml"

# Load Secrets
MYSQL_PASSWORD=$(<${MYSQL_PASSWORD_FILE})
LORIS_ADMIN_PASSWORD=$(<${LORIS_ADMIN_PASSWORD_FILE})
if [[ -n ${SMTP_PASSWORD_FILE} ]]; then
    SMTP_PASSWORD=$(<${SMTP_PASSWORD_FILE})
fi

_update_config() {
    mysql --host=${MYSQL_HOST} --user=${MYSQL_USER} --password=${MYSQL_PASSWORD} \
        -e "UPDATE Config SET Value='$2' WHERE ConfigID=(SELECT ID FROM ConfigSettings WHERE Name='$1')" ${MYSQL_DATABASE}
}

_set_admin_pass() {
    local LORIS_ADMIN_PASSWORD_HASH=$(
        echo -n $2 | php -r 'echo password_hash(file_get_contents("php://stdin"), PASSWORD_DEFAULT);'
    )
    mysql --host=${MYSQL_HOST} --user=${MYSQL_USER} --password=${MYSQL_PASSWORD} \
        -e "UPDATE users SET UserID='${1}', Password_hash='${LORIS_ADMIN_PASSWORD_HASH}', Email='${LORIS_EMAIL}', Active='Y' WHERE ID=1" ${MYSQL_DATABASE}
}

_set_admin_site() {
    mysql --host=${MYSQL_HOST} --user=${MYSQL_USER} --password=${MYSQL_PASSWORD} \
        -e "UPDATE user_psc_rel SET CenterID=(SELECT ID FROM psc WHERE Name='${SITE_NAME}') WHERE ID=1" ${MYSQL_DATABASE}
}

# UPDATE psc SET Name='${SITE_NAME}', Alias='${SITE_ALIAS}', MRI_alias='${MRI_ALIAS}', Study_site='${STUDY_SITE_YN}' WHERE CenterID=1;
# Site will have CenterID=2
_install_site_config() {
    mysql --host=${MYSQL_HOST} --user=${MYSQL_USER} --password=${MYSQL_PASSWORD} ${MYSQL_DATABASE} <<EOF
INSERT INTO psc (Name, Alias, MRI_alias, Study_site) VALUES ('${SITE_NAME}','${SITE_ALIAS}','${MRI_ALIAS}','${STUDY_SITE_YN}');
EOF
}

_initialize_visits() {
    for V in ${VISIT_LABELS}; do
        mysql --host=${MYSQL_HOST} --user=${MYSQL_USER} --password=${MYSQL_PASSWORD} ${MYSQL_DATABASE} <<EOF
INSERT INTO Visit_Windows (Visit_label,  WindowMinDays, WindowMaxDays, OptimumMinDays, OptimumMaxDays, WindowMidpointDays) VALUES ('${V}', ${WINDOW_MIN_DAYS}, ${WINDOW_MAX_DAYS}, ${OPTIMUM_MIN_DAYS}, ${OPTIMUM_MAX_DAYS}, ${WINDOW_MIDPOINT_DAYS});
INSERT INTO visit (VisitName, VisitLabel) VALUES ('${V}', '${V}');
EOF
    done
}

_install_instruments() {
    cd "${BASE_PATH}/tools/"
    for instrument_file in /etc/loris_instruments/*.linst; do
        local instrument_filename=$(basename ${instrument_file})
        local instrument=${instrument_filename%.linst}
        if [[ -f "${BASE_PATH}/project/instruments/${instrument_filename}" ]]; then
            echo "Skipping instrument ${instrument_file} as it already exists."
            continue
        fi
        echo "Installing instrument ${instrument}..."
        cp ${instrument_file} "${BASE_PATH}/project/instruments/"
        echo "Generating ${instrument} SQL tables and testNames..."
        php generate_tables_sql_and_testNames.php <${instrument_file}
        if [[ -n "${INSTALL_DB}"]]; then
            echo "Installing ${instrument} in database..."
            mysql --host=${MYSQL_HOST} --user=${MYSQL_USER} --password=${MYSQL_PASSWORD} ${MYSQL_DATABASE} <"${BASE_PATH}/project/tables_sql/${instrument}.sql"
            echo "Done installing ${instrument}."
        fi
        chown -R lorisadmin:www-data "${BASE_PATH}/project/instruments/" "${BASE_PATH}/project/tables_sql/"
    done
    cd -
}

_install_instrument_battery() {
    echo "Setting up Loris battery with all instruments..."
    mysql --host=${MYSQL_HOST} --user=${MYSQL_USER} --password=${MYSQL_PASSWORD} ${MYSQL_DATABASE} <<EOF
INSERT INTO test_battery (Test_name, AgeMinDays, AgeMaxDays, Active, Stage, Visit_label, CenterID) 
    SELECT Test_name, ${DEFAULT_TEST_AGE_MIN_DAYS}, ${DEFAULT_TEST_AGE_MAX_DAYS}, 'Y', '${DEFAULT_TEST_STAGE}', 'VisitLabel', 2 FROM test_names CROSS JOIN visit;
EOF
}

_install_db_schema() {
    echo "Setting up Loris database schema..."
    for sql_file in $BASE_PATH/SQL/0000*.sql; do
        echo "Installing ${sql_file}..."
        mysql --host=${MYSQL_HOST} --user=${MYSQL_USER} --password=${MYSQL_PASSWORD} ${MYSQL_DATABASE} <${sql_file}
    done
}

_configure_mail() {
    echo "Setting up Loris mail configuration..."
    _update_config "mail" "${LORIS_EMAIL}"
    _update_config "From" "${LORIS_EMAIL}"
    _update_config "Reply-to" "${LORIS_EMAIL}"
    cat <<EOF >/etc/msmtprc
account default
host ${SMTP_HOST}
port ${SMTP_PORT}
auth on
user ${LORIS_EMAIL}
password "${SMTP_PASSWORD}"
from "${LORIS_EMAIL}"
add_missing_from_header on
logfile /var/log/apache2/msmtp.log
EOF

    if [[ -n "${SMTP_TLS}" ]]; then
        cat <<EOF >>/etc/msmtprc
tls on
tls_starttls on
tls_trust_file /etc/ssl/certs/ca-certificates.crt
tls_certcheck on
EOF
    else
        echo "tls off" >>/etc/msmtprc
    fi
}

_install_loris_db_config() {
    _update_config "base" "${BASE_PATH}"
    _update_config "DownloadPath" "${BASE_PATH}"
    _update_config "url" "http://${LORIS_HOST}:${LORIS_PORT}"
    _update_config "host" "${LORIS_HOST}"
    _update_config "data" "${DATA_DIR}/"
    _update_config "imagePath" "${DATA_DIR}/"
    _update_config "MRICodePath" "${DATA_DIR}/"
    _update_config "JWTKey" $(cat /dev/urandom | LC_ALL=C tr -dc 'a-zA-Z0-9!\$^@#%&*()' | fold -w 32 | head -n 1)
}

_install_loris_config_xml() {
    # Copy base configuration.
    cp "${BASE_PATH}/docs/config/config.xml" "${CONFIG_XML}"

    # Replace placeholders with environment variables.
    sed -i \
        -e "s/%HOSTNAME%/${MYSQL_HOST}/g" \
        -e "s/%USERNAME%/${MYSQL_USER}/g" \
        -e "s/%PASSWORD%/${MYSQL_PASSWORD}/g" \
        -e "s/%DATABASE%/${MYSQL_DATABASE}/g" \
        "${CONFIG_XML}"
    chown lorisadmin:www-data "${CONFIG_XML}"
    chmod 660 "${CONFIG_XML}"
}

# Install Loris configuration.

# Installation that modifies DB only.

if [[ -n "${INSTALL_DB}" ]]; then
    echo "Installing Loris database..."
    _install_db_schema

    # Update the Loris admin user password in database.
    _set_admin_pass $LORIS_ADMIN_USER $LORIS_ADMIN_PASSWORD
    _install_loris_db_config

    if [[ -n "${SITE_NAME}" ]]; then
        echo "Setting up Loris site..."
        _install_site_config
    else
        echo "Skipping site initialization."
    fi

    if [[ -n "${VISIT_LABELS}" ]]; then
        echo "Setting up Loris visits..."
        _initialize_visits
    else
        echo "VISIT_LABELS is not set. Skipping visit initialization."
    fi

else
    echo "Skipping database installation."
fi

# Installation that modifies file system.
_install_loris_config_xml

if [[ -d /etc/loris_instruments ]]; then
    echo "Installing instruments..."
    _install_instruments
else
    echo "Instruments directory does not exist. Skipping instrument installation."
fi

if [[ -n "${INSTALL_INSTRUMENT_BATTERY}" ]]; then
    echo "Setting up Loris database with user additions..."
    _install_instrument_battery
else
    echo "Skipping battery installation."
fi

if [[-n "${LORIS_EMAIL}" && -n "${SMTP_HOST}" && -n ${SMTP_PASSWORD}]]; then
    echo "Setting up Loris SMTP configuration..."
    _configure_mail
else
    echo "Skipping SMTP configuration."
fi
