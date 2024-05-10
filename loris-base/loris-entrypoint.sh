#!/usr/bin/env bash

set -e

# Install Loris configuration.
/etc/entrypoint.d/install-loris.sh

exec "$@"
