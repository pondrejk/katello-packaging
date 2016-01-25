#!/bin/bash
# :vim:sw=2:ts=2:et:
#
# This file is installed in /usr/share/foreman/script/foreman-debug.d where
# it is picked by foreman-debug reporting tool. This file contains rules for
# both Katello server and Katello proxy (Satellite 6 / Capsule nodes).
#

# error out if called directly
if [ $BASH_SOURCE == $0 ]
then
  echo "This script should not be executed directly, use foreman-debug instead."
  exit 1
fi

# foreman-debug will truncate any file beyond 5k lines
# for larger files we need to copy the entire file.
copy_files() {
  for FILE in $*; do
    echo "Copying entire file: $FILE"
    if [ \( -f "$FILE" -o -h "$FILE" \) -a \( -r "$FILE" -a -s "$FILE" \) ]; then
      printv " - $FILE"
      SUBDIR=$(dirname $FILE)
      [ ! -d "$DIR$SUBDIR" ] && mkdir -p "$DIR$SUBDIR"
      cp "$FILE" "$DIR$FILE"
    fi
  done
}



# Installer
add_files /var/log/{katello,capsule}-installer/*
add_files /etc/{katello,capsule}-installer/*
add_cmd "find /root/ssl-build -ls | sort -k 11" "katello_ssl_build_dir"
add_cmd "find /etc/pki -ls | sort -k 11" "katello_pki_dir"

# Katello
add_files /etc/pulp/server/plugins.d/*
add_files /etc/foreman/plugins/katello.yaml

# Splice
add_files /var/log/splice/*
add_files /etc/splice/*
add_files /etc/httpd/conf.d/splice.conf

# Candlepin
add_files /var/log/candlepin/*
add_files /var/log/tomcat6/*
add_files /var/log/tomcat/*
add_files /etc/candlepin/candlepin.conf
add_files /etc/tomcat6/server.xml
add_files /etc/tomcat/server.xml

# Pulp
add_files /etc/pulp/*.conf
add_files /etc/httpd/conf.d/pulp.conf
add_files /etc/pulp/server/plugins.conf.d/nodes/distributor/*

# MongoDB (*)
if [ $NOGENERIC -eq 0 ]; then
  add_files /var/log/mongodb/*
  add_files /var/lib/mongodb/mongodb.log*
fi

# Qpidd (*)
if [ $NOGENERIC -eq 0 ]; then
  add_files /etc/qpid/*
  add_files /etc/qpidd.conf
fi
add_cmd "qpid-stat --ssl-certificate=/etc/pki/katello/qpid_client_striped.crt -b amqps://localhost:5671 -q" "qpid_stat_queues"
add_cmd "qpid-stat --ssl-certificate=/etc/pki/katello/qpid_client_striped.crt -b amqps://localhost:5671 -u" "qpid_stat_subscriptions"

# Gofer
add_files /etc/gofer
add_files /var/log/gofer

#foreman-tasks export
if hash foreman-rake  2>/dev/null; then
  echo "Exporting tasks, this may take a few minutes."
  tasks_filename=`foreman-rake foreman_tasks:export_tasks 2> /tmp/tasks_export.log | tail -n 1 | awk '{print $2}'`
  copy_files $tasks_filename
  add_files /tmp/tasks_export.log
fi

# FreeIPA (*)
if [ $NOGENERIC -eq 0 ]; then
  add_files /var/log/ipa*-install.log
  add_files /var/log/ipaupgrade.log
  add_files /var/log/dirsrv/slapd-*/logs/access
  add_files /var/log/dirsrv/slapd-*/logs/errors
  add_files /etc/dirsrv/slapd-*/dse.ldif
  add_files /etc/dirsrv/slapd-*/schema/99user.ldif
fi

# Squid
add_files /etc/squid/squid.conf
add_files /var/log/squid/*

# Qpid Debug
add_cmd "qpid-stat -q --ssl-certificate=/etc/pki/katello/qpid_client_striped.crt -b amqps://localhost:5671" "qpid-stat-q"
add_cmd "qpid-stat -u --ssl-certificate=/etc/pki/katello/qpid_client_striped.crt -b amqps://localhost:5671" "qpid-stat-u"
add_cmd "qpid-stat -c --ssl-certificate=/etc/pki/katello/qpid_client_striped.crt -b amqps://localhost:5671" "qpid-stat-c"
add_cmd "qpid-stat --ssl-certificate=/etc/pki/katello/qpid_client_striped.crt  -b amqps://localhost:5671 -q resource_manager" "qpid-stat-resource_manager"
add_cmd "ps -awfux" "ps-awfux"
add_cmd "ps -efLm" "ps-elfm"
add_cmd "rpm -qa | grep qpid" "qpid-rpm-qa"

add_cmd "mongo pulp_database --eval \"db.reserved_resources.find().pretty().shellPrint()\"" "mongo-reserved_resources"
add_cmd "mongo pulp_database --eval \"db.task_status.find().pretty().shellPrint()\"" "mongo-task_status"

echo "db.task_status.find({state:{\$ne: \"finished\"}}).pretty().shellPrint()" > /tmp/pulp_running_tasks.js

add_cmd "mongo pulp_database /tmp/pulp_running_tasks.js" "pulp-running_tasks"

# Legend:
# * - already collected by sosreport tool (skip when -g option was provided)
