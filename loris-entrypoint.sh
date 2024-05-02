#!/usr/bin/env bash

set -e

_update_config () {
    mysql --host=${MYSQL_HOST} --user=${MYSQL_USER} --password=${MYSQL_PASSWORD} \
          -e "UPDATE Config SET Value='$2' WHERE ConfigID=(SELECT ID FROM ConfigSettings WHERE Name='$1')" ${MYSQL_DATABASE}
}

if [ ! -f /var/www/loris/projects/config.xml ]; then
    echo "Loris configuration does not exist. Installing configuration with values:"
    echo "MYSQL_HOST: ${MYSQL_HOST}"
    echo "MYSQL_USER: ${MYSQL_USER}"
    echo "MYSQL_DATABASE: ${MYSQL_DATABASE}"

    # Read secrets for MySQL password.
    MYSQL_PASSWORD=$(<${MYSQL_PASSWORD_FILE})
    LORIS_ADMIN_PASSWORD=$(<${LORIS_ADMIN_PASSWORD_FILE})
    LORIS_ADMIN_PASSWORD_HASH=$(echo -n $LORIS_ADMIN_PASSWORD | php -r 'echo password_hash(file_get_contents("php://stdin"), PASSWORD_DEFAULT);')
    echo $LORIS_ADMIN_PASSWORD_HASH

    mysql --host=${MYSQL_HOST} --user=${MYSQL_USER} --password=${MYSQL_PASSWORD} \
          -e "UPDATE users SET UserID='${LORIS_ADMIN_USER}', Password_hash='${LORIS_ADMIN_PASSWORD_HASH}', Active='Y' WHERE ID=1" ${MYSQL_DATABASE}

    BASE_PATH="/var/www/loris/"
    DATA_DIR="/data/$PROJECT_NAME/data/"
    _update_config "base" $BASE_PATH
    _update_config "DownloadPath" $BASE_PATH
    _update_config "url" "http://localhost"
    _update_config "host" "localhost"
    _update_config "data" "$DATA_DIR"
    _update_config "imagePath" "$DATA_DIR"
    _update_config "MRICodePath" "$DATA_DIR"
    _update_config "JWTKey" $(openssl rand -base64 32)

    # Copy base configuration.
    cp /var/www/loris/docs/config/config.xml /var/www/loris/project/config.xml

    # Replace placeholders with environment variables.
    sed -i -e "s/%HOSTNAME%/${MYSQL_HOST}/g" \
        -e "s/%USERNAME%/${MYSQL_USER}/g" \
        -e "s/%PASSWORD%/${MYSQL_PASSWORD}/g" \
        -e "s/%DATABASE%/${MYSQL_DATABASE}/g" \
        /var/www/loris/project/config.xml
else
    echo "Loris configuration already exists."
fi

exec apachectl -D FOREGROUND "$@"