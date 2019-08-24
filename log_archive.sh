#!/bin/sh
BACKUPPATH=/BackupDB/Logs
LOGPATH=/var/lib/pgsql/10/data/log
DATE=`date  +"%d%m%y"`

tar -zcvf  $BACKUPPATH/week_backup-$DATE.tar.gz -C $LOGPATH .
echo -e "  \e[1;31m!!! WEEKLY LOGS TAR IS CREATED !!!!\e[0m  "

if [ -s $BACKUPPATH/week_backup-$DATE.tar.gz ]; then

find /var/lib/pgsql/10/data/log -type f -mtime +6 -exec rm {} \;

echo -e "  \e[1;31m!!! DELETED 7 DAYS OLDER LOG FILES  !!!!\e[0m  "

fi
