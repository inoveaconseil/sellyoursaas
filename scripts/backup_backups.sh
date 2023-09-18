#!/bin/bash
# Copy all backups on other locations (on a remote backup server)
#
# Put the following entry into your root cron
#40 4 4 * * /home/jarvis/wwwroot/dolibarr_sellyoursaas/scripts/backup_backups.sh confirm [month|week|none] [osuX]

#TODO Rewrite this in PHP so we can update database of master to flag remote backup success or error. 

#set -e

source /etc/lsb-release

export now=`date +'%Y-%m-%d %H:%M:%S'`

echo
echo "**** ${0}"
echo

if [ "$(id -u)" != "0" ]; then
	echo "This script must be run as root" 1>&2
	exit 100
fi

if [ "x$1" == "x" ]; then
	echo "Usage: ${0} (test|confirm) [month|week|none] [osuX] [--delete]"
	echo "With  month (default) is to keep 1 month of backup using --backup option of rsync"
	echo "      week is to keep 1 week of backup using --backup option of rsync"
	echo "      none is to not archive old versions using the --backup option of rsync. For example when you already do it using snapshots on backup server (recommended)."
	echo "You can also set a group of 4 first letters on username to backup the backup of a limited number of users."
	exit 101
fi

echo "${0} ${@}"
echo "# user id --------> $(id -u)"
echo "# now ------------> $now"
echo "# PID ------------> ${$}"
echo "# PWD ------------> $PWD" 
echo "# arguments ------> ${@}"
echo "# path to me -----> ${0}"
echo "# parent path ----> ${0%/*}"
echo "# my name --------> ${0##*/}"
echo "# realname -------> $(realpath ${0})"
echo "# realname name --> $(basename $(realpath ${0}))"
echo "# realname dir ---> $(dirname $(realpath ${0}))"

export PID=${$}
export scriptdir=$(dirname $(realpath ${0}))
export DOMAIN=`grep '^domain=' /etc/sellyoursaas.conf | cut -d '=' -f 2`
export homedir=`grep '^homedir=' /etc/sellyoursaas.conf | cut -d '=' -f 2`
export backupdir=`grep '^backupdir=' /etc/sellyoursaas.conf | cut -d '=' -f 2`
export remotebackupdir=`grep '^remotebackupdir=' /etc/sellyoursaas.conf | cut -d '=' -f 2`

export testorconfirm=$1

export HISTODIR=`date +%d`
if [ "x$2" == "xw" -o "x$2" == "xweek" ]; then
	HISTODIR=`date +%u`
fi
if [ "x$2" == "xn" -o "x$2" == "xnone" ]; then
	HISTODIR=""
fi

if [ "x$homedir" == "x" ]; then
	export homedir=/mnt/diskhome/home
fi
if [ "x$backupdir" == "x" ]; then
	export backupdir=/mnt/diskbackup/backup
fi
if [ "x$remotebackupdir" == "x" ]; then
	export remotebackupdir=/mnt/diskbackup
fi

# Source
export DIRSOURCE1="/home";
export DIRSOURCE2=$backupdir

# Target
export SERVDESTI=`grep '^remotebackupserver=' /etc/sellyoursaas.conf | cut -d '=' -f 2`
export SERVPORTDESTI=`grep '^remotebackupserverport=' /etc/sellyoursaas.conf | cut -d '=' -f 2`
if [ "x$SERVPORTDESTI" == "x" ]; then
	export SERVPORTDESTI="22"
fi
export USER=`grep '^remotebackupuser=' /etc/sellyoursaas.conf | cut -d '=' -f 2`
export DIRDESTI1="$remotebackupdir/home_"`hostname`;
export DIRDESTI2="$remotebackupdir/backup_"`hostname`;

export EMAILFROM=`grep '^emailfrom=' /etc/sellyoursaas.conf | cut -d '=' -f 2`
export EMAILTO=`grep '^emailsupervision=' /etc/sellyoursaas.conf | cut -d '=' -f 2`
if [ "x$EMAILFROM" == "x" ]; then
	export EMAILFROM=noreply@$DOMAIN
fi
if [ "x$EMAILTO" == "x" ]; then
	export EMAILTO=supervision@$DOMAIN
fi

export DISTRIB_RELEASE=`lsb_release -r -s`

export OPTIONS="-4 --prune-empty-dirs --stats -rlt --chmod=u=rwX";
if [ "x$DISTRIB_RELEASE" == "x20.10" -o "x$DISTRIB_RELEASE" == "x22.04" ]; then
	# Version must be > 20.10 on both side to allow --open-noatime !
	#export OPTIONS="$OPTIONS --open-noatime" 
	export OPTIONS="$OPTIONS"
else 
	export OPTIONS="$OPTIONS --noatime"
fi
if [ "x$2" == "x--delete" ]; then
	export OPTIONS="$OPTIONS --delete --delete-excluded"
fi
if [ "x$3" == "x--delete" ]; then
	export OPTIONS="$OPTIONS --delete --delete-excluded"
fi
if [ "x$4" == "x--delete" ]; then
	export OPTIONS="$OPTIONS --delete --delete-excluded"
fi



if [ "x$USER" == "x" ]; then
	export USER="admin"
fi

instanceserver=`grep '^instanceserver=' /etc/sellyoursaas.conf | cut -d '=' -f 2`

export TESTN=""
if [ "x$testorconfirm" != "xconfirm" ]; then
	TESTN="-n"
fi

echo "DOMAIN=$DOMAIN"
echo "DIRSOURCE1=$DIRSOURCE1"
echo "DIRSOURCE2=$DIRSOURCE2"
echo "SERVDESTI=$SERVDESTI"
echo "SERVPORTDESTI=$SERVPORTDESTI"
echo "EMAILFROM=$EMAILFROM"
echo "EMAILTO=$EMAILTO"
echo "PID=$PID"
echo "instanceserver=$instanceserver"
echo "backupdir=$backupdir"
echo "remotebackupdir=$remotebackupdir"
echo "HISTODIR=$HISTODIR"
echo "OPTIONS=$OPTIONS"
echo "TESTN=$TESTN"
echo "testorconfirm = $testorconfirm"

if [ "x$SERVDESTI" == "x" ]; then
	echo "Can't find name of remote backup server (remotebackupserver=) in /etc/sellyoursaas.conf" 1>&2
	echo "Usage: ${0} (test|confirm) [osuX]"
	echo
	exit 102
fi

if [ "x$DOMAIN" == "x" ]; then
	echo "Value for domain seems to not be set into /etc/sellyoursaas.conf" 1>&2
	echo "Usage: ${0} (test|confirm) [osuX]"
	echo
	exit 103
fi


export errstring=""
export atleastoneerror=0
declare -A ret1
declare -A ret2
declare -A listServ
declare -A listDir
declare -A listDirByIp
totalinstancessaved=0
totalinstancesfailed=0


# the following line is to have an empty dir to clear the last incremental directories
[ -d $HOME/emptydir ] || mkdir $HOME/emptydir

indexServ=0
# Loop on each target server
for SERVDESTICURSOR in `echo $SERVDESTI | sed -e 's/,/ /g'`
do
	listServ[$indexServ]=$SERVDESTICURSOR
    ((indexServ++))
	ret1[$SERVDESTICURSOR]=0
	ret2[$SERVDESTICURSOR]=0
done

indexServDir=0
for SERVDIRCURSOR in `echo "$remotebackupdir" | sed -e 's/,/ /g'`
do
        listDir[$indexServDir]=$SERVDIRCURSOR
        ((indexServDir++))
done

nbrMax=${#listServ[@]}
((nbrMax--))

for x in $(seq 0 $nbrMax)
do
        ipFromIndex=${listServ[$x]}
        listDirByIp[$ipFromIndex]=${listDir[$x]}
done

for ip in ${!listDirByIp[@]}; do
	IPSERVBACKUP=${ip}
	DIRFORIP=${listDirByIp[${ip}]}
	export DIRDESTI1="$DIRFORIP/home_"`hostname`;
	export DIRDESTI2="$DIRFORIP/backup_"`hostname`;
	echo
	echo `date +'%Y-%m-%d %H:%M:%S'`" Do rsync of $DIRSOURCE1 to remote $USER@$IPSERVBACKUP:$DIRDESTI1..."
	
	export RSYNC_RSH="ssh -p $SERVPORTDESTI"
	if [ "x$HISTODIR" == "x" ]; then
		export command="rsync $TESTN -x --exclude-from=$scriptdir/backup_backups.exclude $OPTIONS $DIRSOURCE1/* $USER@$IPSERVBACKUP:$DIRDESTI1";
	else
		export command="rsync $TESTN -x --exclude-from=$scriptdir/backup_backups.exclude $OPTIONS --backup --backup-dir=$DIRDESTI1/backupold_$HISTODIR $DIRSOURCE1/* $USER@$IPSERVBACKUP:$DIRDESTI1";
	fi
	echo `date +'%Y-%m-%d %H:%M:%S'`" $command";
	
	
	$command 2>&1
   	# WARNING: The set of rescommand must be just after the $command. No echo between.
	rescommand=$?
    if [ "x$rescommand" != "x0" ]; then
		ret1[$IPSERVBACKUP]=$rescommand
    	echo "ERROR Failed to make rsync for $DIRSOURCE1 to $IPSERVBACKUP. ret=${ret1[$IPSERVBACKUP]}."
    	echo "Command was: $command"
    	export errstring="$errstring\n"`date '+%Y-%m-%d %H:%M:%S'`" Dir $DIRSOURCE1 to $IPSERVBACKUP. ret=${ret1[$IPSERVBACKUP]}. Command was: $command\n"
    fi
    
    sleep 2

done

# Loop on each target server to make backup of SOURCE1
# for SERVDESTICURSOR in `echo $SERVDESTI | sed -e 's/,/ /g'`
# do
# 	#echo `date +'%Y-%m-%d %H:%M:%S'`" Do rsync of emptydir to $SERVDESTICURSOR:$DIRDESTI1/backupold_$HISTODIR/..."
# 	#rsync $TESTN -a $HOME/emptydir/ $USER@$SERVDESTICURSOR:$DIRDESTI1/backupold_$HISTODIR/

# 	echo
# 	echo `date +'%Y-%m-%d %H:%M:%S'`" Do rsync of $DIRSOURCE1 to remote $USER@$SERVDESTICURSOR:$DIRDESTI1..."
	
# 	export RSYNC_RSH="ssh -p $SERVPORTDESTI"
# 	if [ "x$HISTODIR" == "x" ]; then
# 		export command="rsync $TESTN -x --exclude-from=$scriptdir/backup_backups.exclude $OPTIONS $DIRSOURCE1/* $USER@$SERVDESTICURSOR:$DIRDESTI1";
# 	else
# 		export command="rsync $TESTN -x --exclude-from=$scriptdir/backup_backups.exclude $OPTIONS --backup --backup-dir=$DIRDESTI1/backupold_$HISTODIR $DIRSOURCE1/* $USER@$SERVDESTICURSOR:$DIRDESTI1";
# 	fi
# 	echo `date +'%Y-%m-%d %H:%M:%S'`" $command";
	
	
# 	$command 2>&1
#    	# WARNING: The set of rescommand must be just after the $command. No echo between.
# 	rescommand=$?
#     if [ "x$rescommand" != "x0" ]; then
# 		ret1[$SERVDESTICURSOR]=$rescommand
#     	echo "ERROR Failed to make rsync for $DIRSOURCE1 to $SERVDESTICURSOR. ret=${ret1[$SERVDESTICURSOR]}."
#     	echo "Command was: $command"
#     	export errstring="$errstring\n"`date '+%Y-%m-%d %H:%M:%S'`" Dir $DIRSOURCE1 to $SERVDESTICURSOR. ret=${ret1[$SERVDESTICURSOR]}. Command was: $command\n"
#     fi
    
#     sleep 2
# done


# Loop on each target server to make backup of SOURCE2
if [[ "x$instanceserver" != "x0" ]]; then
	echo
	echo `date +'%Y-%m-%d %H:%M:%S'`" Do rsync of customer directories $DIRSOURCE2/osu to remote $SERVDESTI..."

	#for SERVDESTICURSOR in `echo $SERVDESTI | sed -e 's/,/ /g'`
	#do
	#	echo `date +'%Y-%m-%d %H:%M:%S'`" Do rsync of emptydir to $SERVDESTICURSOR:$DIRDESTI2/backupold_$HISTODIR/..."
	#	rsync $TESTN -a $HOME/emptydir/ $USER@$SERVDESTICURSOR:$DIRDESTI2/backupold_$HISTODIR/
	#done

	export nbdu=0
	
	for i in 'a' 'b' 'c' 'd' 'e' 'f' 'g' 'h' 'i' 'j' 'k' 'l' 'm' 'n' 'o' 'p' 'q' 'r' 's' 't' 'u' 'v' 'w' 'x' 'y' 'z' '0' '1' '2' '3' '4' '5' '6' '7' '8' '9' ; do
		echo
		echo `date +'%Y-%m-%d %H:%M:%S'`" ----- Process directory $backupdir/osu$i"
		nbofdir=`ls -d $backupdir/osu$i* 2>/dev/null | wc -l`
		if [ "x$nbofdir" != "x0" ]; then
			# Test if we force backup on a given dir
			if [ "x$3" != "x" ]; then
				if [ "x$3" != "xosu$i" -a "x$3" != "x--delete" ]; then
					echo "Ignored (param 3 is $3)."
					continue
				fi
			fi

			# for SERVDESTICURSOR in `echo $SERVDESTI | sed -e 's/,/ /g'`
			# do
			for ip in ${!listDirByIp[@]}
			do
				IPSERVBACKUP=${ip}
				DIRFORIP=${listDirByIp[${ip}]}
				export DIRDESTI1="$DIRFORIP/home_"`hostname`;
				export DIRDESTI2="$DIRFORIP/backup_"`hostname`;
				export RSYNC_RSH="ssh -p $SERVPORTDESTI"
				if [ "x$HISTODIR" == "x" ]; then
		    	    export command="rsync $TESTN -x --exclude-from=$scriptdir/backup_backups.exclude $OPTIONS $DIRSOURCE2/osu$i* $USER@$SERVDESTICURSOR:$DIRDESTI2";
		    	else 
		    	    export command="rsync $TESTN -x --exclude-from=$scriptdir/backup_backups.exclude $OPTIONS --backup --backup-dir=$DIRDESTI2/backupold_$HISTODIR $DIRSOURCE2/osu$i* $USER@$SERVDESTICURSOR:$DIRDESTI2";
		    	fi
	        	echo `date +'%Y-%m-%d %H:%M:%S'`" $command";

		        $command 2>&1
			   	# WARNING: The set of rescommand must be just after the $command. No echo between.
				rescommand=$?
		        if [ "x$rescommand" != "x0" ]; then
		        	ret2[$ip]=$((${ret2[$ip]} + 1));
		        	echo "ERROR Failed to make rsync for $DIRSOURCE2/osu$i to $ip. ret=${ret2[$ip]}."
		        	echo "Command was: $command"
		        	((totalinstancesfailed += nbofdir))
		        	export errstring="$errstring\n"`date '+%Y-%m-%d %H:%M:%S'`" Dir osu$i to $ip. ret=${ret2[$ip]}. Command was: $command\n"
		        else
		          ((totalinstancessaved += nbofdir))
		        	echo
		        	# Success of backup of backup, we try to calculate disk usage for each dir
		        	echo `date +'%Y-%m-%d %H:%M:%S'`" Scan dir named $DIRSOURCE2/osu$i*"
		        	for osudir in `ls -d $DIRSOURCE2/osu$i*`
		        	do
		        		export osudirbase=`basename $osudir`
		        		if [[ $nbdu -lt 50 ]]; then
			        		export osudirbase=`basename $osudir`
			        		if [[ -d $homedir/$osudirbase/ ]]; then
			        			# Frequency in day to update duc database
			        			DELAYUPDATEDUC=-15
			        			echo `date +'%Y-%m-%d %H:%M:%S'`" Search if a recent duc file exists with find $homedir/$osudirbase/.duc.db -mtime $DELAYUPDATEDUC 2>/dev/null | wc -l"
				        		export found=`find $homedir/$osudirbase/.duc.db -mtime $DELAYUPDATEDUC 2>/dev/null | wc -l`
				        		if [ "x$found" = "x0" ]; then
				        			# No recent .duc.db found, so we calculate it
				        			echo `date +'%Y-%m-%d %H:%M:%S'`" No recent .duc.db into $homedir/$osudirbase and nb already updated = $nbdu, so we update it."
				        			echo "duc index $homedir/$osudirbase -x -m 3 -d $homedir/$osudirbase/.duc.db"
					        		duc index $homedir/$osudirbase -x -m 3 -d $homedir/$osudirbase/.duc.db
					        		chown $osudirbase.$osudirbase $homedir/$osudirbase/.duc.db
					        		export nbdu=$((nbdu+1))
					        	else
					        		echo `date +'%Y-%m-%d %H:%M:%S'`" File $homedir/$osudirbase/.duc.db was recently updated"
					        	fi
					        else
				        		echo `date +'%Y-%m-%d %H:%M:%S'`" Dir $homedir/$osudirbase/ does not exists, we cancel duc for $homedir/$osudirbase/"
					        fi
			        	else
			        		echo `date +'%Y-%m-%d %H:%M:%S'`" Max nb of update to do reached ($nbdu), we cancel duc for $homedir/$osudirbase/"
			        	fi
		        	done
		        fi
				
				sleep 2
			done
	    else
	    	echo "No directory found starting with name $backupdir/osu$i"
			export errstring="$errstring\n"`date '+%Y-%m-%d %H:%M:%S'`" No directory found starting with name $backupdir/osu$i\n"
	    fi
	done
fi

echo
echo `date +'%Y-%m-%d %H:%M:%S'`" End with errstring=$errstring"
echo


# Loop on each targeted server for return code
export atleastoneerror=0

for SERVDESTICURSOR in `echo $SERVDESTI | sed -e 's/,/ /g'`
do
	echo `date +'%Y-%m-%d %H:%M:%S'`" End for $SERVDESTICURSOR ret1[$SERVDESTICURSOR]=${ret1[$SERVDESTICURSOR]} ret2[$SERVDESTICURSOR]=${ret2[$SERVDESTICURSOR]}"
    
	if [ "x${ret1[$SERVDESTICURSOR]}" != "x0" ]; then
		atleastoneerror=1
	elif [ "x${ret2[$SERVDESTICURSOR]}" != "x0" ]; then
		atleastoneerror=1
	fi
done


# Delete temporary emptydir
rmdir $HOME/emptydir


# Send email if there is one error
if [ "x$atleastoneerror" != "x0" ]; then
	echo "Send email to $EMAILTO to warn about backup error"
	echo -e "Failed to make copy backup to remote backup server(s) $SERVDESTI.\nNumber of instances successfully saved: $totalinstancessaved\nNumber of instances unsuccessfully saved: $totalinstancesfailed\nErrors or warnings are:\n$errstring" | mail -aFrom:$EMAILFROM -s "[Warning] Backup of backup to remote server(s) failed for "`hostname` $EMAILTO
	
	exit 1
fi

if [ "x$3" != "x" -a "x$3" != "x--delete" ]; then
	echo "Script was called for only one of few given instances. No email or supervision event sent on success in such situation."
else
	echo "Send email to $EMAILTO to inform about backup success"
	echo -e "The backup of backup for "`hostname`" to remote backup server $SERVDESTI succeed.\nNumber of instances successfully saved: $totalinstancessaved\n$errstring" | mail -aFrom:$EMAILFROM -s "[Backup of Backup - "`hostname`"] Backup of backup to remote server succeed" $EMAILTO
fi
echo

exit 0
