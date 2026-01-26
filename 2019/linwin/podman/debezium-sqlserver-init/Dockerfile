FROM mcr.microsoft.com/mssql/server:2019-latest

COPY ./debezium.* /etc/sqlserver/

USER root
RUN apt-get update && apt-get install -y iproute2 iputils-ping net-tools && rm -rf /var/lib/apt/lists/*
USER mssql
