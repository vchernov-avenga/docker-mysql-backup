FROM alpine:3.19.0

RUN apk add --update \
        tzdata \
        bash \
        mysql-client \
        gzip \
        openssl \
        mariadb-connector-c && \
    rm -rf /var/cache/apk/*

COPY ["run.sh", "backup.sh", "restore.sh", "/delete.sh", "/"]
RUN mkdir /backup && \
    chmod 777 /backup && \
    chmod 755 /run.sh /backup.sh /restore.sh /delete.sh && \
    touch /mysql_backup.log && \
    chmod 666 /mysql_backup.log

VOLUME ["/backup"]

CMD /run.sh
