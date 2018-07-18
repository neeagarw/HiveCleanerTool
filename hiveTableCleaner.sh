#!/bin/sh
# uncomment for debug mode
#set -xv

# Global
pit=$(date '+%Y-%m-%d')
echo "$pit START"
tmp_timestamp=$(date -d "$pit" '+%s')
old_timestamp=$(( $tmp_timestamp - 432000  ))
cur_timestamp="$(date +%s)"

# Functions

# CLEANUP - DEPRECATED FOR THE MOMENT BECAUSE ALL TABLES SEEM TO BE FROM SAME LOCATION
#rm -f /opt/hal/hiveTableCleaner/tables_loc

# get list of tables
get_tables()
{
sudo -u hdfs hive -e "show tables" | egrep '_([0-9]{22})' > /opt/hal/hiveTableCleaner/new_tables
sudo -u hdfs hive -e "show tables" | egrep '_([0-9]{14})$' > /opt/hal/hiveTableCleaner/old_tables
}

# get table location - DEPRECATED FOR THE MOMENT BECAUSE ALL TABLES SEEM TO BE FROM SAME LOCATION
#for f in `cat /opt/hal/hiveTableCleaner/new_tables`
#  do
#    hive -e "describe formatted $f" | grep "$f" >> /opt/hal/hiveTableCleaner/tables_loc
#  done

# Close pid
close_pid()
{
if [ -f $PF ]; then rm $PF; fi
}



# Logic

if [ -f /var/run/hiveTableCleaner_*.pid ]
  then
        OPF="$(find /var/run/hiveTableCleaner_*)"
        apid="$(cat $OPF)"
        `kill -9 $apid`
        rm -f $OPF
        echo "Old Pid Detected"
        echo "OLD PROCESS KILLED"
  else
        echo "Registering Pid"
fi

# Create Pid File
PF=/var/run/hiveTableCleaner_$cur_timestamp.pid
echo $$ > $PF

# Get tables function
get_tables

# get last modified dates and delete tables older than 5 days
for f in `cat /opt/hal/hiveTableCleaner/new_tables`
  do
    description="$(hive -e "describe formatted $f")"
    t_date=$(grep "CreateTime:" <<< "$description" | sed "s/CreateTime:[ \t]*//g")
    t_type=$(grep "Table Type:" <<< "$description" | sed "s/Table Type:[ \t]*//g" | sed "s/^.*_//g")
#    t_date=$(hadoop fs -stat /user/hive/warehouse/$f | cut -d" " -f1) - DEPRECATED
    t_timestamp=$(date -d "$t_date" '+%s')
    if [ $t_timestamp -lt $old_timestamp ]
      then echo "$f is from: $t_date and is older than: $old_timestamp -> Will be deleted"
      sudo -u hdfs hive -e "DROP $t_type $f"
    fi
  done

for f in `cat /opt/hal/hiveTableCleaner/old_tables`
  do
    description="$(hive -e "describe formatted $f")"
    t_date=$(grep "CreateTime:" <<< "$description" | sed "s/CreateTime:[ \t]*//g")
    t_type=$(grep "Table Type:" <<< "$description" | sed "s/Table Type:[ \t]*//g" | sed "s/^.*_//g")
#    t_date=$(hadoop fs -stat /user/hive/warehouse/$f | cut -d" " -f1) - DEPRECATED
    t_timestamp=$(date -d "$t_date" '+%s')
    if [ $t_timestamp -lt $old_timestamp ]
      then echo "$f is from: $t_date and is older than: $old_timestamp -> Will be deleted"
      sudo -u hdfs hive -e "DROP $t_type $f"
    fi
  done

close_pid

exit 0
