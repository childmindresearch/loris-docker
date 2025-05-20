#!/usr/bin/env bash

set -e

# usage: file_env VAR [DEFAULT]
#    ie: file_env 'XYZ_DB_PASSWORD' 'example'
# (will allow for "$XYZ_DB_PASSWORD_FILE" to fill in the value of
#  "$XYZ_DB_PASSWORD" from a file, especially for Docker's secrets feature)
_file_env() {
    local var="$1"
    local fileVar="${var}_FILE"
    local def="${2:-}"
    if [[ "${!var:-}" && "${!fileVar:-}" ]]; then
        echo "Both $var and $fileVar are set (but are exclusive). $var takes precedence."
    fi
    local val="$def"
    if [[ "${!var:-}" ]]; then
        val="${!var}"
    elif [[ "${!fileVar:-}" ]]; then
        val="$(<"${!fileVar}")"
    fi
    export "$var"="$val"
    unset "$fileVar"
}

_mysql_cmd() {
    echo "Running MYSQL command: ${1}"
    mysql -s --host=${MYSQL_HOST} --user=${MYSQL_USER} --password=${MYSQL_PASSWORD} --database=${MYSQL_DATABASE} -e "${1}"
}

_mysql_cmd_quiet() {
    mysql -s --host=${MYSQL_HOST} --user=${MYSQL_USER} --password=${MYSQL_PASSWORD} --database=${MYSQL_DATABASE} -e "${1}"
}

_mysql_root_cmd() {
    echo "Running MYSQL ROOT command: ${1}"
    mysql -s --host=${MYSQL_HOST} --user=root --password=${MYSQL_ROOT_PASSWORD} -e "${1}"
}

_update_config() {
    _mysql_cmd "UPDATE Config SET Value='${2}' WHERE ConfigID=(SELECT ID FROM ConfigSettings WHERE Name='${1}')"
    # mysql -s --host=${MYSQL_HOST} --user=${MYSQL_USER} --password=${MYSQL_PASSWORD} \
    #     -e "UPDATE Config SET Value='$2' WHERE ConfigID=(SELECT ID FROM ConfigSettings WHERE Name='$1')" ${MYSQL_DATABASE}
}

_set_admin_pass() {
    local LORIS_ADMIN_PASSWORD_HASH=$(
        echo -n $2 | php -r 'echo password_hash(file_get_contents("php://stdin"), PASSWORD_DEFAULT);'
    )
    _mysql_cmd "UPDATE users SET UserID='${1}', Password_hash='${LORIS_ADMIN_PASSWORD_HASH}', Email='${LORIS_EMAIL}', Active='Y' WHERE ID=1"
    echo "Admin user password set."
    # mysql -s --host=${MYSQL_HOST} --user=${MYSQL_USER} --password=${MYSQL_PASSWORD} \
    #     -e "UPDATE users SET UserID='${1}', Password_hash='${LORIS_ADMIN_PASSWORD_HASH}', Email='${LORIS_EMAIL}', Active='Y' WHERE ID=1" ${MYSQL_DATABASE}
}

_add_admin_site() {
    _mysql_cmd "INSERT INTO user_psc_rel (UserID, CenterID) VALUES (1, (SELECT CenterID FROM psc WHERE Name='${SITE_NAME}'))"
}

# UPDATE psc SET Name='${SITE_NAME}', Alias='${SITE_ALIAS}', MRI_alias='${MRI_ALIAS}', Study_site='${STUDY_SITE_YN}' WHERE CenterID=1;
# Site will have CenterID=2
_install_site_config() {
    _mysql_cmd "INSERT INTO psc (Name, Alias, MRI_alias, Study_site) VALUES ('${SITE_NAME}','${SITE_ALIAS}','${MRI_ALIAS}','${STUDY_SITE_YN}')"
}

_initialize_visits() {
    for VISIT in ${VISIT_LABELS}; do
        echo "Installing visit ${VISIT}..."
        _mysql_cmd "INSERT INTO Visit_Windows (Visit_label,  WindowMinDays, WindowMaxDays, OptimumMinDays, OptimumMaxDays, WindowMidpointDays) VALUES ('${VISIT}', ${WINDOW_MIN_DAYS}, ${WINDOW_MAX_DAYS}, ${OPTIMUM_MIN_DAYS}, ${OPTIMUM_MAX_DAYS}, ${WINDOW_MIDPOINT_DAYS})"
        _mysql_cmd "INSERT INTO visit (VisitName, VisitLabel) VALUES ('${VISIT}', '${VISIT}');"

        for COHORT in ${COHORT_LABELS}; do
            echo "Installing visit-cohort relationship for ${VISIT} and ${COHORT}..."
            _mysql_cmd "INSERT INTO visit_project_cohort_rel (VisitID, ProjectCohortRelID) VALUES (
                (SELECT VisitID FROM visit WHERE VisitName='${VISIT}'),
                    (
                        SELECT ProjectCohortRelID FROM project_cohort_rel 
                            WHERE ProjectID=(SELECT ProjectID FROM Project WHERE Name='${PROJECT_NAME}') 
                            AND CohortID=(SELECT CohortID FROM cohort WHERE title='${COHORT}')
                    )
                )"
        done
    done
}

# Install relationships for default project and cohorts.
_initialize_cohorts() {
    for COHORT in ${COHORT_LABELS}; do
        # Install Cohorts, skipping default values.
        if [[ "${COHORT}" != "Control" && "${COHORT}" != "Experimental" ]]; then
            echo "Installing cohort ${COHORT}..."
            _mysql_cmd "INSERT INTO cohort (title, useEDC, WindowDifference) VALUES ('${COHORT}', false, 'optimal')"
            #             mysql -s --host=${MYSQL_HOST} --user=${MYSQL_USER} --password=${MYSQL_PASSWORD} ${MYSQL_DATABASE} <<EOF
            # INSERT INTO cohort (title, useEDC, WindowDifference) VALUES ('${COHORT}', false, 'optimal');
            # EOF
        fi

        # Install Project-Cohort relationships.
        echo "Installing project-cohort relationship for ${COHORT}..."
        _mysql_cmd "INSERT INTO project_cohort_rel (ProjectID, CohortID) VALUES ( 
                    (SELECT ProjectID FROM Project WHERE Name = '${PROJECT_NAME}'), 
                    (SELECT CohortID from cohort where title = '${COHORT}'))"
    done
}

_install_instruments() {
    cd "${BASE_PATH}/tools/"
    shopt -s nullglob
    for instrument_file in /run/loris_instruments/*.linst; do
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
        if [[ "${INSTALL_DB}" == "True" ]]; then
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
    _mysql_cmd "INSERT INTO test_battery (Test_name, AgeMinDays, AgeMaxDays, Active, Stage, CohortID, Visit_label, CenterID) SELECT Test_name, ${DEFAULT_TEST_AGE_MIN_DAYS}, ${DEFAULT_TEST_AGE_MAX_DAYS}, 'Y', '${DEFAULT_TEST_STAGE}', (SELECT CohortID FROM cohort WHERE title = '${DEFAULT_COHORT}'), VisitLabel, 2 FROM test_names CROSS JOIN visit"
}

_create_db_and_user() {
    echo "Creating database: ${MYSQL_DATABASE}..."
    echo "Root Password: ${MYSQL_ROOT_PASSWORD}"
    mysql --host=${MYSQL_HOST} --user=root --password=${MYSQL_ROOT_PASSWORD} \
        -e "CREATE DATABASE IF NOT EXISTS ${MYSQL_DATABASE} ;"
    # Create the database user
    echo "Creating user: ${MYSQL_USER}..."
    mysql --host=${MYSQL_HOST} --user=root --password=${MYSQL_ROOT_PASSWORD} \
        -e "CREATE USER '${MYSQL_USER}'@'%' IDENTIFIED BY '${MYSQL_PASSWORD}' ;"
    # Grant all privileges on the database to the user
    # NOTE: Cannot GRANT ALL as this is disallowed by RDS.
    echo "Granting privileges to user: ${MYSQL_USER}..."
    # RELOAD, PROCESS, SHOW DATABASES, REPLICATION SLAVE, REPLICATION CLIENT, CREATE USER,
    mysql --host=${MYSQL_HOST} --user=root --password=${MYSQL_ROOT_PASSWORD} \
        -e "GRANT ALTER, ALTER ROUTINE, CREATE, CREATE ROUTINE, CREATE TEMPORARY TABLES, CREATE VIEW, DELETE, DROP, EVENT, EXECUTE, INDEX, INSERT, LOCK TABLES, REFERENCES, SELECT, SHOW VIEW, TRIGGER, UPDATE ON ${MYSQL_DATABASE}.* TO '${MYSQL_USER}'@'%' WITH GRANT OPTION;"
}

_create_couch_db() {
    echo "Creating CouchDB database: ${COUCH_DATABASE}..."
    curl \
        -H 'Content-Type: application/json' \
        -X POST http://${COUCH_USERNAME}:${COUCH_PASSWORD}@${COUCH_HOSTNAME}:${COUCH_PORT}/_replicate \
        -d '{"source":"http://couchdb.loris.ca:5984/dataquerytool-1_0_0", "target":"'"${COUCH_DATABASE}"'", "create_target":true}'
}

_install_db_schema() {
    echo "Setting up Loris database schema..."
    for sql_file in ${BASE_PATH}/SQL/0000*.sql; do
        echo "Installing ${sql_file}..."
        mysql --host=${MYSQL_HOST} --user=${MYSQL_USER} --password=${MYSQL_PASSWORD} --database=${MYSQL_DATABASE} <${sql_file}
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
    _update_config "base" "${BASE_PATH}/"
    _update_config "DownloadPath" "${BASE_PATH}/"
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

    if [[ -n ${COUCH_HOSTNAME} ]]; then
        echo "Installing CouchDB configuration..."
        sed -i \
            -e "s/%COUCH_DATABASE%/${COUCH_DATABASE}/g" \
            -e "s/%COUCH_HOSTNAME%/${COUCH_HOSTNAME}/g" \
            -e "s/%COUCH_PORT%/${COUCH_PORT}/g" \
            -e "s/%COUCH_USERNAME%/${COUCH_USERNAME}/g" \
            -e "s/%COUCH_PASSWORD%/${COUCH_PASSWORD}/g" \
            "${CONFIG_XML}"
    fi

    if [[ "${MANUAL_PSCID_GENERATION}" == "True" ]]; then
        # Set PSCID generation to manual.
        echo "Setting PSCID generation to manual..."
        xmlstarlet ed -L \
            -d "config/study/PSCID/structure/seq[@type='siteAbbrev']" \
            -d "config/study/PSCID/structure/seq/@length" \
            -i "config/study/PSCID/structure/seq[@type='alphanumeric']" -t attr -n maxLength -v 20 \
            -i "config/study/PSCID/structure/seq[@type='alphanumeric']" -t attr -n minLength -v 1 \
            -u "config/study/PSCID/generation" -v "user" \
            "${CONFIG_XML}"
    fi

    chown lorisadmin:www-data "${CONFIG_XML}"
    chmod 660 "${CONFIG_XML}"
}

_install_config_settings() {
    for f in /run/loris_config_settings/*.txt; do
        local config_label=$(basename "${f}" .txt)
        echo "Installing config setting ${config_label}..."
        # Check if the file exists in the database.
        local exists=$(_mysql_cmd_quiet "SELECT COUNT(*) FROM ConfigSettings WHERE Label='${config_label}'")
        echo "Config setting ${config_label} exists in the database: ${exists}"
        if [[ "${exists}" -eq 0 ]]; then
            echo "Config setting ${config_label} does not exist in the database. Skipping."
            continue
        fi

        # Push contents of file to DB.
        local content=$(<"${f}")
        local config_name=$(_mysql_cmd_quiet "SELECT Name FROM ConfigSettings WHERE Label='${config_label}'")
        echo "Updating config setting ${config_label} with name ${config_name} and contents ${content}..."
        _update_config "${config_name}" "${content}"
    done
}

_install_db_import() {
    for f in /run/loris_db_import/*.csv; do
        local table_name=$(basename ${f} .csv)
        echo "Installing DB import for table ${table_name}..."
        # Check if the file exists in the database.
        local exists=$(_mysql_cmd "SELECT COUNT(*) FROM information_schema.tables WHERE table_name='${table_name}'")
        if [[ "${exists}" -eq 0 ]]; then
            echo "Table ${table_name} does not exist in the database. Skipping."
            continue
        fi

        # Push contents of file to DB.
        _mysql_cmd "LOAD DATA LOCAL INFILE '${f}' INTO TABLE ${table_name} FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '\"' LINES TERMINATED BY '\n';"
    done
}

### Main ###

# Load Secrets
_file_env MYSQL_PASSWORD
_file_env MYSQL_ROOT_PASSWORD
_file_env LORIS_ADMIN_PASSWORD
_file_env SMTP_PASSWORD

if [[ -z "${MYSQL_HOST}" || -z "${MYSQL_USER}" || -z "${MYSQL_PASSWORD}" || -z "${MYSQL_DATABASE}" ]]; then
    echo "Missing required environment database environment variables:"
    if [[ -z "${MYSQL_HOST}" ]]; then
        echo "MYSQL_HOST is not set."
    fi
    if [[ -z "${MYSQL_USER}" ]]; then
        echo "MYSQL_USER is not set."
    fi
    if [[ -z "${MYSQL_PASSWORD}" ]]; then
        echo "MYSQL_PASSWORD is not set."
    fi
    if [[ -z "${MYSQL_DATABASE}" ]]; then
        echo "MYSQL_DATABASE is not set."
    fi
    exit 1
fi

if [[ -z "${LORIS_ADMIN_USER}" || -z "${LORIS_ADMIN_PASSWORD}" ]]; then
    echo "Missing required environment variables:"
    if [[ -z "${LORIS_ADMIN_USER}" ]]; then
        echo "LORIS_ADMIN_USER is not set."
    fi
    if [[ -z "${LORIS_ADMIN_PASSWORD}" ]]; then
        echo "LORIS_ADMIN_PASSWORD is not set."
    fi
    exit 1
fi

if [[ "${CREATE_DB}" == "True" ]]; then
    echo "Creating database and user..."
    _create_db_and_user
else
    echo "Skipping database creation."
fi

# Installation that modifies DB only.
if [[ "${INSTALL_DB}" == "True" ]]; then
    echo "Installing Loris database..."
    _install_db_schema

    # Update the Loris admin user password in database.
    _set_admin_pass $LORIS_ADMIN_USER $LORIS_ADMIN_PASSWORD
    _install_loris_db_config

    if [[ -n "${SITE_NAME}" ]]; then
        echo "Setting up Loris site..."
        _install_site_config
        _add_admin_site
    else
        echo "Skipping site initialization."
    fi

    if [[ -n "${COHORT_LABELS}" ]]; then
        echo "Setting up Loris cohorts, and cohort-project relationship..."
        _initialize_cohorts
    else
        echo "COHORT_LABELS is not set. Skipping cohort initialization."
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

if [[ "${CREATE_COUCH}" == "True" ]]; then
    echo "Creating CouchDB database..."
    _create_couch_db
else
    echo "Skipping CouchDB creation."
fi

if [[ -d /run/loris_instruments ]]; then
    echo "Installing instruments..."
    _install_instruments
else
    echo "Instruments directory does not exist. Skipping instrument installation."
fi

if [[ "${INSTALL_INSTRUMENT_BATTERY}" == "True" ]]; then
    echo "Setting up Loris database with user additions..."
    _install_instrument_battery
else
    echo "Skipping battery installation."
fi

if [[ -n "${LORIS_EMAIL}" && -n "${SMTP_HOST}" && -n "${SMTP_PASSWORD}" ]]; then
    echo "Setting up Loris SMTP configuration..."
    _configure_mail
else
    echo "Skipping SMTP configuration."
fi

if [[ -d /run/loris_config_settings ]]; then
    echo "Installing Loris config settings..."
    _install_config_settings
else
    echo "Loris config settings directory does not exist. Skipping config settings installation."
fi

if [[ -d /run/loris_db_import ]]; then
    echo "Installing Loris DB import..."
    _install_db_import
else
    echo "Loris DB import directory does not exist. Skipping DB import installation."
fi
