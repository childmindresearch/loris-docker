#!/usr/bin/env bash

set -e

if [[ -n "${DEBUG_CONTAINER}" ]]; then
    echo "DEBUG_CONTAINER is set. Skipping Loris configuration installation."
elif [[ -f "${CONFIG_XML}" ]]; then
    echo "Loris configuration exists. Skipping Loris configuration installation."
else
    # Install Loris configuration.
    echo "Configuring Loris..."
    /etc/entrypoint.d/install-loris.sh
fi

exec "$@"
