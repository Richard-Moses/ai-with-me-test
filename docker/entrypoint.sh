#!/bin/sh
set -e
echo "Starting oeson-microservice on port ${PORT:-8080} as UID $(id -u)"
exec node /app/src/index.js
