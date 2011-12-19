#!/bin/bash
#########################################################################
# Script:	check_mysql_slavestatus.sh				#
# Author:	Claudio Kuenzler www.claudiokuenzler.com		#
# Purpose:	Monitor MySQL Replication status with Nagios		#
# Description:	Connects to given MySQL hosts and checks for running 	#
#		SLAVE state and delivers additional info		#
# Original:	This script is a modified version of 			#
#		check mysql slave sql running written by dhirajt	#
# Thanks to:	Victor Balada Diaz for his ideas added on 20080930	#
#		Soren Klintrup for stuff added on 20081015		#
# History:	2008041700 Original Script modified			#
#		2008041701 Added additional info if status OK		#
#		2008041702 Added usage of script with params -H -u -p	#
#		2008041703 Added bindir variable for multiple platforms	#
#		2008041704 Added help because mankind needs help	#
#		2008093000 Using /bin/sh instead of /bin/bash		#
#		2008093001 Added port for MySQL server			#
#		2008093002 Added mysqldir if mysql binary is elsewhere	#
#		2008101501 Changed bindir/mysqldir to use PATH		#
#		2008101501 Use $() instead of `` to avoid forks		#
#		2008101501 Use ${} for variables to prevent problems	#
#		2008101501 Check if required commands exist		#
#		2008101501 Check if mysql connection works		#
#		2008101501 Exit with unknown status at script end	#
#		2008101501 Also display help if no option is given	#
#		2008101501 Add warning/critical check to delay		#
#		2011062200 Add perfdata					#
#########################################################################
# Usage: ./check_mysql_slavestatus.sh -H dbhost -P port -u dbuser -p dbpass
#########################################################################
help="\ncheck_mysql_slavestatus.sh (c) 2008 GNU licence
Usage: ./check_mysql_slavestatus.sh -H host P port -u username -p password\n
Options:\n-H Hostname\n-P Port of MySQL Server (3306 is standard)\n-u Username of DB-User\n-p Password of DBUser\n
Attention: The DB-user you type in must have CLIENT REPLICATION rights on the DB-server.\n"

STATE_OK=0		# define the exit code if status is OK
STATE_WARNING=1		# define the exit code if status is Warning (not really used)
STATE_CRITICAL=2	# define the exit code if status is Critical
STATE_UNKNOWN=3		# define the exit code if status is Unknown
PATH=/usr/local/groundwork/mysql/bin:/usr/local/bin:/usr/bin:/bin # Set path
crit="No"		# what is the answer of MySQL Slave_SQL_Running for a Critical status?
ok="Yes"		# what is the answer of MySQL Slave_SQL_Running for an OK status?
warn_delay=10 # warning at this delay
crit_delay=60 # critical at this delay

for cmd in mysql cut grep [ 
do
 if ! `which ${cmd} 1>/dev/null`
 then
  echo "UNKNOWN: ${cmd} does not exist, please check if command exists and PATH is correct"
  exit ${STATE_UNKNOWN}
 fi
done

# Check for people who need help - aren't we all nice ;-)
#########################################################################
if [ "${1}" = "--help" -o "${#}" = "0" ]; 
	then 
	echo -e "${help}";
	exit 1;
fi

# Important given variables for the DB-Connect
#########################################################################
while getopts "H:P:u:p:" Input;
do
	case ${Input} in
	H)	host=${OPTARG};;
	P)	port=${OPTARG};;
	u)	user=${OPTARG};;
	p)	password=${OPTARG};;
	\?)	echo "Wrong option given. Please use options -H for host, -P for port, -u for user and -p for password"
		exit 1
		;;
	esac
done

# Connect to the DB server and check for informations
#########################################################################
if ! `mysql -h ${host} -P ${port} -u ${user} --password=${password} -e 'show slave status\G' 1>/dev/null 2>/dev/null`
then
 echo CRITICAL: unable to connect to server
 exit ${STATE_CRITICAL}
fi
check=$(mysql -h ${host} -P ${port} -u ${user} --password=${password} -e 'show slave status\G' | grep Slave_SQL_Running | cut -d: -f2)
masterinfo=$(mysql -h ${host} -P ${port} -u ${user} --password=${password} -e 'show slave status\G' | grep Master_Host | cut -d: -f2)
delayinfo=$(mysql -h ${host} -P ${port} -u ${user} --password=${password} -e 'show slave status\G' | grep Seconds_Behind_Master | cut -d: -f2)

# Output of different exit states
#########################################################################
if [ ${check} = "NULL" ]; then 
echo CRITICAL: Slave SQL Running is answering Null
exit ${STATE_CRITICAL};
fi

if [ ${check} = ${crit} ]; then 
echo CRITICAL: ${host} Slave SQL Running: ${check}
exit ${STATE_CRITICAL};
fi

if [ ${check} = ${ok} ]; then
 if [ "${delayinfo}" -ge "${warn_delay}" ]
 then
  if [ "${delayinfo}" -ge "${crit_delay}" ]
  then
   echo "CRITICAL: slave is ${delayinfo} seconds behind master | delay=${delayinfo}s"
   exit ${STATE_CRITICAL}
  else
   echo "WARNING: slave is ${delayinfo} seconds behind master | delay=${delayinfo}s"
   exit ${STATE_WARNING}
  fi
 else
  echo "OK: Slave SQL running: ${check} / master: ${masterinfo} / slave is ${delayinfo} seconds behind master | delay=${delayinfo}s"
  exit ${STATE_OK};
 fi
fi

echo "UNKNOWN: should never reach this part"
exit ${STATE_UNKNOWN}
