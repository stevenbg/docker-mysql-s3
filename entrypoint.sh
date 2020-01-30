#!/bin/sh

set -e

if [ -z "${SCHEDULE}" ]; then
    exec sh backup.sh
else
    echo "${SCHEDULE} /bin/sh /backup.sh" | crontab -
    exec cron -f
fi
