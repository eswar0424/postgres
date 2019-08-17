#!/bin/sh
########## Archive Directory for archives coming from Master Server ###############################
pold=/var/lib/pgsql/pg_log_archive

############################## Archive and Base Backup Directory after moving from pg_log_archive ###############
pnew=/var/lib/pgsql/pg_archive_move

######################## Postgres Startup Path #############################
startup=/etc/init.d/postgresql-9.5

######################## Postgres cluster Path #############################
clust=/var/lib/pgsql/9.5

####################### Postgres Base Directory ###########################
basepath=/var/lib/pgsql

################################ Master Database IP Address ##################
host='10.248.100.229'
DOA=`date  +"%d%m%y"`
############################## Configuration File ###############################
configfile='postgresql.auto.conf'

########################## Check if Directory pg_log_move Exists #######################################
if [ ! -d "$pold" ]; then
    mkdir -p $pold
    chown -R postgres. $pold
fi

if [ -d "$pnew" ]; then
    rm -rf $pnew/*
    mv -f  $pold/* $pnew/.
    tar -zcvf  $pnew/log_file_backup-$DOA.tar --exclude='*.tar' $pnew
    find $pnew/. -type 'f' -not -name "*.tar" | xargs rm
fi

########################## Check if not Directory then create pg_log_move and move  #######################################
if [ ! -d "$pnew" ]; then
    mkdir -p $pnew
    rm -rf $pnew/*
    mv -f  $pold/* $pnew/.
    tar -zcvf  $pnew/log_file_backup-$DOA.tar --exclude='*.tar' $pnew
    find $pnew/. -type 'f' -not -name "*.tar" | xargs rm
fi

#################### Stopping Slave Database Cluster and wait for 10 seconds ##############################
echo Stopping PostgreSQL
$startup stop
sleep 10

#################### Check if postgreSQL is running after execute cluster stop command then killall is used ################
status=`netstat -nelpt | grep 5432`
if [[ ! -z $status  ]]; then
    killall -9 postgres
fi

############## Deleting existing data directory #######################################3
echo Cleaning up old cluster directory
rm -rf $clust/data

########################### Starting Base Backup #############################################
echo Starting base backup as eoffice
$clust/bin/pg_basebackup -h $host  -D $clust/data -U eoffice -v -P


############################ Find the values $configfile parameters
maxsh=`grep -ri "shared_buffers =" $clust/data/$configfile | awk '{print $3}'`
maxec=`grep -ri "effective_cache_size =" $clust/data/$configfile | awk '{print $3}'`

################################# Copy Base backup to pg_log_move ################################
echo "Copy BaseBackup  To New Location"
#cp -rf $clust/data $pnew/.
rm -rf $clust/data/pg_logs/*
tar -zcvf $pold/db_file_backup-$DOA.tar $clust/data
###################### Creating Recovery.conf file ###########################################
echo Writing recovery.conf file

cat > $clust/data/recovery.conf <<- _EOF1_
standby_mode = 'on'
primary_conninfo = 'host=$host port=5432 user=eoffice'
trigger_file = '/tmp/postgresql.trigger'
_EOF1_

############################ Setting hot_standby on ###########################################
echo Setting hot standby on
sed -i "s/hot_standby = 'off'/hot_standby = 'on'/g" $clust/data/$configfile

############################ Setting Archive off  ##############################################
echo Setting archive off  
sed -i "s/archive_mode = 'on'/#archive_mode = 'off'/g" $clust/data/$configfile
sed -i 's/archive_command/#archive_command/g' $clust/data/$configfile

############################ Setting effective cache  ##########################################
echo Setting effective Cache to 4 GB
sed -i "s/effective_cache_size = $maxec/effective_cache_size = '4GB'/g" $clust/data/$configfile

############################ Setting Shared Buffers  ############################################
echo Setting Shared Buffer to 1 GB
sed -i "s/shared_buffers = $maxsh/shared_buffers = '1GB'/g" $clust/data/$configfile


####################### Changing Ownership of /var/lib/pgsql to postgres ##########################
echo Changing Ownership
chown -R postgres. $basepath

###################### Starting PostgreSQL Database  #############################################
echo Startging PostgreSQL
$startup start

