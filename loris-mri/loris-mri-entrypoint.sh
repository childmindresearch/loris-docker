#!/usr/bin/env bash

set -e

export CONFIG_XML="${BASE_PATH}/project/config.xml"

if [[ -n "${DEBUG_CONTAINER}" ]]; then
    echo "DEBUG_CONTAINER is set. Skipping Loris configuration installation."
elif [[ -f "${CONFIG_XML}" ]]; then
    echo "Loris configuration exists. Skipping Loris configuration installation."
else
    echo "### Starting Installation ###"
    # Install Loris configuration.
    echo "Configuring Loris..."
    /etc/entrypoint.d/install-loris.sh
    echo "Done configuring Loris."

    # Install Loris MRI configuration.
    echo "Configuring Loris-MRI..."
    /etc/entrypoint.d/install-loris-mri.sh
    echo "Done configuring Loris-MRI."
    echo "### Installation Complete ###"
fi

echo "Executing CMD: $@"
exec "$@"
