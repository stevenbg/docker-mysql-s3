#! /bin/sh
set -e

mv_s3 () {
    SRC_FILE=$1
    DEST_FILE=$2

    if [ -z "${S3_ENDPOINT}" ]; then
        AWS_ARGS=""
    else
        AWS_ARGS="--endpoint-url ${S3_ENDPOINT}"
    fi

    if [ -z "${S3_FOLDER}" ]; then
        S3_URL="s3://${S3_BUCKET}/${DEST_FILE}"
    else
        S3_URL="s3://${S3_BUCKET}/${S3_FOLDER}/${DEST_FILE}"
    fi

    echo "Moving to ${S3_URL}..."
    aws $AWS_ARGS s3 mv "$SRC_FILE" "$S3_URL"

    if [ $? != 0 ]; then
        >&2 echo "Upload of ${DEST_FILE} failed"
    fi
}

do_dump () {
    DUMP_FILE="/tmp/dump.sql"
    mysqldump $MYSQL_HOST_OPTS $MYSQLDUMP_OPTIONS -r $DUMP_FILE --databases ${@}
    bzip2 -9 $DUMP_FILE
    DUMP_FILE="${DUMP_FILE}.bz2"
}

if [ -z "${S3_BUCKET}" ]; then
    echo "S3_BUCKET cannot be empty"
    exit 1
fi
if [ -z "${MYSQL_HOST}" ]; then
    echo "MYSQL_HOST cannot be empty"
    exit 1
fi
if [ -z "${MYSQL_USER}" ]; then
    echo "MYSQL_USER cannot be empty"
    exit 1
fi
if [ -z "${MYSQLDUMP_DATABASE}" ]; then
    echo "MYSQLDUMP_DATABASE cannot be empty"
    exit 1
fi


export AWS_ACCESS_KEY_ID=$S3_ACCESS_KEY_ID
export AWS_SECRET_ACCESS_KEY=$S3_SECRET_ACCESS_KEY
export AWS_DEFAULT_REGION=$S3_REGION

MYSQL_HOST_OPTS="-h $MYSQL_HOST -P $MYSQL_PORT -u$MYSQL_USER"
if [ ! -z "${MYSQL_PASSWORD}" ]; then
    MYSQL_HOST_OPTS="$MYSQL_HOST_OPTS -p$MYSQL_PASSWORD"
fi
DUMP_START_TIME=$(date -u +"%Y%m%d-%H%M")

if [ "${SPLIT_FILES}" == "yes" ]; then
    for DB in $MYSQLDUMP_DATABASE; do
        echo "Dumping ${DB}..."
        # sets $DUMP_FILE
        do_dump $DB

        if [ -z "${S3_FILENAME}" ]; then
            S3_FILE="${DUMP_START_TIME}.${DB}.sql.bz2"
        else
            S3_FILE="${DUMP_START_TIME}.${S3_FILENAME}.${DB}.sql.bz2"
        fi

        mv_s3 $DUMP_FILE $S3_FILE
    done
else
    echo "Dumping ${MYSQLDUMP_DATABASE}..."
    # sets $DUMP_FILE
    do_dump $MYSQLDUMP_DATABASE

    if [ -z "${S3_FILENAME}" ]; then
        S3_FILE="${DUMP_START_TIME}.dump.sql.bz2"
    else
        S3_FILE="${DUMP_START_TIME}.${S3_FILENAME}.sql.bz2"
    fi

    mv_s3 $DUMP_FILE $S3_FILE
fi

echo "Done"
