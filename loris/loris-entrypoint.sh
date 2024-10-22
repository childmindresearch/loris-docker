#!/usr/bin/env bash

set -e

export CONFIG_XML="${BASE_PATH}/project/config.xml"

if [[ -n "${DEBUG_CONTAINER}" ]]; then
    echo "DEBUG_CONTAINER is set. Skipping Loris configuration installation."
elif [[ -f "${CONFIG_XML}" ]]; then
    echo "Loris configuration exists. Skipping Loris configuration installation."
else
    # Install Loris configuration.
    echo "Configuring Loris..."
    /etc/entrypoint.d/install-loris.sh
    echo "Done configuring Loris."
fi

echo "Executing CMD: $@"
exec "$@"
