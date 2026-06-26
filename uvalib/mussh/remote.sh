#!/bin/bash
CLIST=`sudo docker ps --format "{{.Names}}"`
for c in $CLIST; do
	echo ${c};
	sudo docker exec ${c} printenv | grep MYSQL_HOST
	sudo docker exec ${c} grep -R db_ /var/aegir/config/server_master/apache/vhost.d
done
