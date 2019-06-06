FROM alpine:3.9

RUN apk update
RUN apk add --no-cache mysql-client python py-pip tzdata
RUN pip install awscli
RUN apk del py-pip

# mysql parameters
# --net_buffer_length=16384 is a usual default, affects line lengths
ENV MYSQLDUMP_OPTIONS "--quote-names --quick --add-drop-table --add-locks --allow-keywords --disable-keys --extended-insert --single-transaction --create-options --comments --net_buffer_length=16384"
ENV MYSQLDUMP_DATABASE ""
ENV MYSQL_HOST "localhost"
ENV MYSQL_PORT "3306"
ENV MYSQL_USER "root"
ENV MYSQL_PASSWORD ""

# S3 target bucket and credentials
ENV S3_ACCESS_KEY_ID ""
ENV S3_SECRET_ACCESS_KEY ""
ENV S3_BUCKET ""

# extra options
ENV S3_REGION "eu-central-1"
ENV S3_ENDPOINT ""
ENV S3_FOLDER ""
ENV S3_FILENAME ""
ENV SPLIT_FILES "no"

# cron format schedule in the respective timezone
ENV SCHEDULE ""
ENV TZ "Europe/London"

COPY entrypoint.sh entrypoint.sh
COPY backup.sh backup.sh

ENTRYPOINT [ "sh", "entrypoint.sh" ]
