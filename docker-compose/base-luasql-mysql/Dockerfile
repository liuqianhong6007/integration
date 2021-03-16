FROM nickblah/lua:5.1.5-luarocks-ubuntu
MAINTAINER liuqianhong
RUN apt-get update && apt-get install -y git gcc libmysqlclient-dev && luarocks install luasql-mysql MYSQL_DIR=/var/lib/mysql MYSQL_INCDIR=/usr/include/mysql