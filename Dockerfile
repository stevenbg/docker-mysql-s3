FROM mysql:8.0.16

RUN apt-get update && apt-get install --no-install-recommends -y \
    python python-pip python-setuptools tzdata cron bzip2

RUN pip install awscli
RUN apt-get purge -y python-pip python-setuptools \
    mysql-common mysql-community-client mysql-community-server-core
RUN apt-get autoremove -y
RUN apt-get install --no-install-recommends -y mysql-community-client-core
RUN apt-get clean && rm -rf /var/lib/apt/lists/*

##
# mysql parameters
# --net_buffer_length=16384 is a usual default, affects line lengths
# --column-statistics=0 is for backward compat with 5.7
ENV MYSQLDUMP_OPTIONS "--column-statistics=0 --quote-names --quick --add-drop-table --add-locks --allow-keywords --disable-keys --extended-insert --single-transaction --create-options --comments --net_buffer_length=16384"
ENV MYSQLDUMP_DATABASE ""
# if you specify multiple space-separated databases
ENV SPLIT_FILES "no"
ENV MYSQL_HOST "localhost"
ENV MYSQL_PORT "3306"
ENV MYSQL_USER "root"
ENV MYSQL_PASSWORD ""

##
# S3 target bucket and credentials
ENV S3_ACCESS_KEY_ID ""
ENV S3_SECRET_ACCESS_KEY ""
ENV S3_BUCKET ""

ENV S3_REGION "eu-central-1"
ENV S3_ENDPOINT ""
# no leading or trailing /
ENV S3_FOLDER ""
# this will be added to the generated filename
ENV S3_FILENAME ""

##
# valid values: smtp
ENV ON_FAILURE ""
# the SMTP has to use TLS user/pass auth
ENV SMTP_SERVER "smtp.eu.mailgun.org:587"
ENV SMTP_USERNAME ""
ENV SMTP_PASSWORD ""
ENV SMTP_RCPT ""
ENV SMTP_FROM ""
ENV SMTP_MESSAGE "Backup failure."

##
# cron format schedule in the respective timezone
ENV SCHEDULE ""
ENV TZ "Europe/London"

COPY entrypoint.sh entrypoint.sh
COPY backup.sh backup.sh

ENTRYPOINT [ "sh", "entrypoint.sh" ]
