#!/usr/bin/env bash

set -e

# Install Loris configuration.
/etc/entrypoint.d/install-loris.sh

# Install Loris MRI configuration.
/etc/entrypoint.d/install-loris-mri.sh

exec "$@"
