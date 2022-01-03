#!/bin/dash

. /myenv.sh

mv_s3 () {
    SRC_FILE=$1
    DEST_FILE=$2

    if [ -z "${S3_ENDPOINT_URL}" ]; then
        AWS_ARGS=""
    else
        AWS_ARGS="--endpoint-url ${S3_ENDPOINT_URL}"
    fi

    if [ -z "${S3_STORAGE_CLASS}" ]; then
        S3_ARGS=""
    else
        S3_ARGS="--storage-class ${S3_STORAGE_CLASS}"
    fi

    if [ -z "${S3_FOLDER}" ]; then
        S3_URL="s3://${S3_BUCKET}/${DEST_FILE}"
    else
        S3_URL="s3://${S3_BUCKET}/${S3_FOLDER}/${DEST_FILE}"
    fi

    echo "Moving to ${S3_URL}..."
    aws $AWS_ARGS s3 mv "$SRC_FILE" "$S3_URL" $S3_ARGS
}

do_dump () {
    echo "Dumping ${@}..."
    DUMP_FILE="/tmp/dump.sql"
    mysqldump $MYSQL_HOST_OPTS $MYSQLDUMP_OPTIONS -r $DUMP_FILE ${@} && \
    CLONE_DB="${@}_b"
    echo "Drop $CLONE_DB ..." && \
    mysql $MYSQL_HOST_OPTS -e "DROP DATABASE IF EXISTS $CLONE_DB" && \
    echo "Create $CLONE_DB ..." && \
    mysql $MYSQL_HOST_OPTS -e "CREATE DATABASE $CLONE_DB" && \
    echo "Import $CLONE_DB ..." && \
    mysql $MYSQL_HOST_OPTS $CLONE_DB < $DUMP_FILE && \
    echo "Zipping..." && \
    bzip2 -f9 $DUMP_FILE && \
    DUMP_FILE="${DUMP_FILE}.bz2"
}

error_panic () {
    echo "backup error"

    if [ "${ON_FAILURE}" = "smtp" ]; then
        echo "sending email"
        echo "${SMTP_MESSAGE}" | \
        mailx -v -r "${SMTP_FROM}" \
            -s "Failed backup of ${MYSQL_HOST}/${MYSQLDUMP_DATABASE}" \
            -S smtp="${SMTP_SERVER}" \
            -S smtp-use-starttls \
            -S ssl-verify=ignore \
            -S smtp-auth=login \
            -S smtp-auth-user="${SMTP_USERNAME}" \
            -S smtp-auth-password="${SMTP_PASSWORD}" \
            ${SMTP_RCPT}
    fi

    exit 1
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

# if [ "${SPLIT_FILES}" = "yes" ]; then
    for DB in $MYSQLDUMP_DATABASE; do
        # sets $DUMP_FILE

        if ! do_dump $DB; then
            error_panic
        fi

        if [ -z "${S3_FILENAME}" ]; then
            S3_FILE="${DUMP_START_TIME}.${DB}.sql.bz2"
        else
            S3_FILE="${DUMP_START_TIME}.${S3_FILENAME}.${DB}.sql.bz2"
        fi

        if ! mv_s3 $DUMP_FILE $S3_FILE; then
            error_panic
        fi
    done
# else
#     # sets $DUMP_FILE
#     if ! do_dump $MYSQLDUMP_DATABASE; then
#         error_panic
#     fi

#     if [ -z "${S3_FILENAME}" ]; then
#         S3_FILE="${DUMP_START_TIME}.dump.sql.bz2"
#     else
#         S3_FILE="${DUMP_START_TIME}.${S3_FILENAME}.sql.bz2"
#     fi

#     if ! mv_s3 $DUMP_FILE $S3_FILE; then
#         error_panic
#     fi
# fi

echo "Done"
