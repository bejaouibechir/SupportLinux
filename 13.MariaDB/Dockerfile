FROM mariadb:11.4

WORKDIR /app

ENV MYSQL_ROOT_PASSWORD=rootpass \
    MYSQL_DATABASE=test_db \
    MYSQL_USER=test_user \
    MYSQL_PASSWORD=testpass

RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        mariadb-client && \
    rm -rf /var/lib/apt/lists/*

EXPOSE 3306
