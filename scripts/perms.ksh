#!/bin/bash
#--------------------------------------------------------#
# Script to force permission on expected default values
#--------------------------------------------------------#

if [ "$(id -u)" != "0" ]; then
	echo "This script must be run as root" 1>&2
	exit 100
fi

# possibility to change the directory where instances are stored
export targetdir=`grep '^targetdir=' /etc/sellyoursaas.conf | cut -d '=' -f 2`
if [[ "x$targetdir" == "x" ]]; then
	export targetdir="/home/jail/home"
fi

# possibility to change the directory where backup instances are stored
export backupdir=`grep '^backupdir=' /etc/sellyoursaas.conf | cut -d '=' -f 2`
if [[ "x$backupdir" == "x" ]]; then
	export backupdir="/mnt/diskbackup/backup"
fi

echo "Search to know if we are a master server in /etc/sellyoursaas.conf"
masterserver=`grep '^masterserver=' /etc/sellyoursaas.conf | cut -d '=' -f 2`
instanceserver=`grep '^instanceserver=' /etc/sellyoursaas.conf | cut -d '=' -f 2`

export pathtospamdir=`grep '^pathtospamdir=' /etc/sellyoursaas-public.conf | cut -d '=' -f 2`
if [ "x$pathtospamdir" == "x" ]; then
	export pathtospamdir="/tmp/spam"
fi

# Go into a safe dir
cd /tmp

#echo "Remplacement user apache par www-data"
#find . -user apache -exec chown www-data {} \;

#echo "Remplacement group apache par www-data"
#find . -group apache -exec chgrp www-data {} \;

# Owner root on logs and backups dir
echo "Set owner and permission on logs and backup directory"
[ -d /home/jarvis/logs ] || mkdir /home/jarvis/logs;
[ -d /mnt/diskbackup ] || mkdir /mnt/diskbackup;
[ -d /home/jarvis/backup ] || mkdir /home/jarvis/backup;
[ -d /home/jarvis/backup/conf ] || mkdir /home/jarvis/backup/conf;
[ -d /home/jarvis/backup/mysql ] || mkdir /home/jarvis/backup/mysql;
[ -d /home/jarvis/wwwroot ] || mkdir /home/jarvis/wwwroot;
chown root.admin /home/jarvis/logs; chmod 770 /home/jarvis/logs; 
chown jarvis:jarvis /mnt/diskbackup; 
chown jarvis:jarvis /home/jarvis/backup; chown jarvis:jarvis /home/jarvis/backup/conf; chown jarvis:jarvis /home/jarvis/backup/mysql; 
chown jarvis:jarvis /home/jarvis/wwwroot

# Permissions on SSH config and private key files
echo "Set owner and permission on admin ssh files"
[ -s /home/jarvis/.ssh/config ] && chmod go-rwx /home/jarvis/.ssh/config && chown jarvis:jarvis /home/jarvis/.ssh/config
[ -s /home/jarvis/.ssh/id_rsa ] && chmod go-rwx /home/jarvis/.ssh/id_rsa && chown jarvis:jarvis /home/jarvis/.ssh/id_rsa
[ -s /home/jarvis/.ssh/id_rsa.pub ] && chmod go-wx /home/jarvis/.ssh/id_rsa.pub && chown jarvis:jarvis /home/jarvis/.ssh/id_rsa.pub
[ -s /home/jarvis/.ssh/id_rsa_sellyoursaas ] && chmod go-rwx /home/jarvis/.ssh/id_rsa_sellyoursaas && chown jarvis:jarvis /home/jarvis/.ssh/id_rsa_sellyoursaas 
[ -s /home/jarvis/.ssh/id_rsa_sellyoursaas.pub ] && chmod go-wx /home/jarvis/.ssh/id_rsa_sellyoursaas.pub && chown jarvis:jarvis /home/jarvis/.ssh/id_rsa_sellyoursaas.pub 


echo "Set owner and permission on /home/jarvis/wwwroot/dolibarr_documents/ (except sellyoursaas)"
chmod g+ws /home/jarvis/wwwroot/dolibarr_documents/
chown admin.www-data /home/jarvis/wwwroot/dolibarr_documents
for fic in `ls /home/jarvis/wwwroot/dolibarr_documents | grep -v sellyoursaas`; 
do 
	chown -R admin.www-data "/home/jarvis/wwwroot/dolibarr_documents/$fic"
	chmod -R ug+rw "/home/jarvis/wwwroot/dolibarr_documents/$fic"
	find "/home/jarvis/wwwroot/dolibarr_documents/$fic" -type d -exec chmod u+wx {} \;
	find "/home/jarvis/wwwroot/dolibarr_documents/$fic" -type d -exec chmod g+ws {} \;
done
if [ -d /home/jarvis/wwwroot/dolibarr_documents/users/temp/odtaspdf ]; then
	chown www-data.www-data /home/jarvis/wwwroot/dolibarr_documents/users/temp/odtaspdf
fi

if [[ "x$masterserver" == "x1" ]]; then
	echo We are on a master server, Set owner and permission on /home/jarvis/wwwroot/dolibarr_documents/sellyoursaas
	chown -R admin.www-data /home/jarvis/wwwroot/dolibarr_documents/sellyoursaas
	chmod -R ug+rw /home/jarvis/wwwroot/dolibarr_documents/sellyoursaas/git
	chmod -R ug+rw /home/jarvis/wwwroot/dolibarr_documents/sellyoursaas/packages
	chmod -R ug+rw /home/jarvis/wwwroot/dolibarr_documents/sellyoursaas/temp
	chmod -R ug+rw /home/jarvis/wwwroot/dolibarr_documents/sellyoursaas/crt
fi

echo Set owner and permission on /etc/sellyoursaas.conf
if [ ! -s /etc/sellyoursaas.conf ]; then
	echo > /etc/sellyoursaas.conf
fi
chown -R root.admin /etc/sellyoursaas.conf
chmod g-wx /etc/sellyoursaas.conf
chmod o-rwx /etc/sellyoursaas.conf

echo Set owner and permission on /etc/sellyoursaas-pubic.conf
if [ ! -s /etc/sellyoursaas-public.conf ]; then
	echo > /etc/sellyoursaas-public.conf
fi
chown -R root.admin /etc/sellyoursaas-public.conf
chmod a+r /etc/sellyoursaas-public.conf
chmod a-wx /etc/sellyoursaas-public.conf

echo Set owner and permission on /home/jarvis/wwwroot/dolibarr
chown -R jarvis:jarvis /home/jarvis/wwwroot/dolibarr
chmod -R a-w /home/jarvis/wwwroot/dolibarr
chmod -R u+w /home/jarvis/wwwroot/dolibarr/.git

if [ -d /home/jarvis/wwwroot/dolibarr_nltechno ]; then
	echo Set owner and permission on /home/jarvis/wwwroot/dolibarr_nltechno
	chmod -R a-w /home/jarvis/wwwroot/dolibarr_nltechno 2>/dev/null
	chmod -R u+w /home/jarvis/wwwroot/dolibarr_nltechno/.git 2>/dev/null
fi

if [ -d /home/jarvis/wwwroot/dolibarr_sellyoursaas ]; then
	echo Set owner and permission on /home/jarvis/wwwroot/dolibarr_sellyoursaas
	chmod -R a-w /home/jarvis/wwwroot/dolibarr_sellyoursaas 2>/dev/null
	chmod -R u+w /home/jarvis/wwwroot/dolibarr_sellyoursaas/.git 2>/dev/null
fi

echo Set owner and permission on /home/jarvis/wwwroot/dolibarr/htdocs/conf/conf.php
if [ -f /home/jarvis/wwwroot/dolibarr/htdocs/conf/conf.php ]; then
	chown www-data.admin /home/jarvis/wwwroot/dolibarr/htdocs/conf/conf.php
	chmod o-rwx /home/jarvis/wwwroot/dolibarr/htdocs/conf/conf.php
fi

echo Set owner and permission on SSL certificates /etc/apache2/*.key and /etc/lestencrypt
for fic in `ls /etc/apache2/ | grep '.key$'`; 
do 
	chown root.www-data /etc/apache2/$fic
	chmod ug+r /etc/apache2/$fic
	chmod o-rwx /etc/apache2/$fic
done
chmod go+x /etc/letsencrypt/archive
chmod go+x /etc/letsencrypt/live

if [[ "x$masterserver" == "x1" ]]; then
	echo We are on a master server, so we clean old temp files 
	find /home/jarvis/wwwroot/dolibarr_documents/sellyoursaas/temp -maxdepth 1 -name "*.tmp" -type f -mtime +2 -delete
fi

echo "Nettoyage vieux fichiers log"
echo find /home/jarvis/wwwroot/dolibarr_documents -maxdepth 1 -name "dolibarr*.log*" -type f -mtime +2 -delete
find /home/jarvis/wwwroot/dolibarr_documents -maxdepth 1 -name "dolibarr*.log*" -type f -mtime +2 -delete

echo "Nettoyage vieux /tmp"
echo find /tmp -mtime +30 -name 'phpsendmail*.*' -delete
find /tmp -mtime +30 -name 'phpsendmail*.*' -delete

echo "Check files for antispam system and create them if not found"
[ -d /home/jarvis/wwwroot/dolibarr_documents/sellyoursaas_local/spam ] || mkdir -p /home/jarvis/wwwroot/dolibarr_documents/sellyoursaas_local/spam;
[ -s /home/jarvis/wwwroot/dolibarr_documents/sellyoursaas_local/spam/blacklistmail ] || cp -p /home/jarvis/wwwroot/dolibarr_documents/sellyoursaas/spam/blacklistmail /home/jarvis/wwwroot/dolibarr_documents/sellyoursaas_local/spam/;
[ -s /home/jarvis/wwwroot/dolibarr_documents/sellyoursaas_local/spam/blacklistip ] || cp -p /home/jarvis/wwwroot/dolibarr_documents/sellyoursaas/spam/blacklistip /home/jarvis/wwwroot/dolibarr_documents/sellyoursaas_local/spam/;
[ -s /home/jarvis/wwwroot/dolibarr_documents/sellyoursaas_local/spam/blacklistfrom ] || cp -p /home/jarvis/wwwroot/dolibarr_documents/sellyoursaas/spam/blacklistfrom /home/jarvis/wwwroot/dolibarr_documents/sellyoursaas_local/spam/;
[ -s /home/jarvis/wwwroot/dolibarr_documents/sellyoursaas_local/spam/blacklistcontent ] || cp -p /home/jarvis/wwwroot/dolibarr_documents/sellyoursaas/spam/blacklistcontent /home/jarvis/wwwroot/dolibarr_documents/sellyoursaas_local/spam/;
chmod a+rwx /home/jarvis/wwwroot/dolibarr_documents/sellyoursaas_local/spam; chmod a+rw /home/jarvis/wwwroot/dolibarr_documents/sellyoursaas_local/spam/*;
chown -R admin.www-data /home/jarvis/wwwroot/dolibarr_documents/sellyoursaas_local;

[ -d $pathtospamdir ] || mkdir $pathtospamdir;
[ -s $pathtospamdir/blacklistmail ] || cp -p /home/jarvis/wwwroot/dolibarr_documents/sellyoursaas_local/spam/blacklistmail $pathtospamdir/;
[ -s $pathtospamdir/blacklistip ] || cp -p /home/jarvis/wwwroot/dolibarr_documents/sellyoursaas_local/spam/blacklistip $pathtospamdir/;
[ -s $pathtospamdir/blacklistfrom ] || cp -p /home/jarvis/wwwroot/dolibarr_documents/sellyoursaas_local/spam/blacklistfrom $pathtospamdir/;
[ -s $pathtospamdir/blacklistcontent ] || cp -p /home/jarvis/wwwroot/dolibarr_documents/sellyoursaas_local/spam/blacklistcontent $pathtospamdir/;
chmod a+rwx $pathtospamdir; chmod a+rw $pathtospamdir/*
chown admin.www-data $pathtospamdir/*


# Special actions...


# Create some links
echo "Create links for fail2ban conf"
cd /etc/fail2ban/filter.d
if [ ! -e /home/jarvis/wwwroot/dolibarr_sellyoursaas/etc/fail2ban/filter.d/email-dolibarr-ruleskoblacklist.conf ]; then
	ln -fs /home/jarvis/wwwroot/dolibarr_sellyoursaas/etc/fail2ban/filter.d/email-dolibarr-ruleskoblacklist.conf
fi
if [ ! -e /home/jarvis/wwwroot/dolibarr_sellyoursaas/etc/fail2ban/filter.d/email-dolibarr-ruleskoquota.conf ]; then
	ln -fs /home/jarvis/wwwroot/dolibarr_sellyoursaas/etc/fail2ban/filter.d/email-dolibarr-ruleskoquota.conf
fi
if [ ! -e /home/jarvis/wwwroot/dolibarr_sellyoursaas/etc/fail2ban/filter.d/email-dolibarr-rulesko.conf ]; then
	ln -fs /home/jarvis/wwwroot/dolibarr_sellyoursaas/etc/fail2ban/filter.d/email-dolibarr-rulesko.conf
fi
if [ ! -e /home/jarvis/wwwroot/dolibarr_sellyoursaas/etc/fail2ban/filter.d/email-dolibarr-rulesall.conf ]; then
	ln -fs /home/jarvis/wwwroot/dolibarr_sellyoursaas/etc/fail2ban/filter.d/email-dolibarr-rulesall.conf
fi
if [ ! -e /home/jarvis/wwwroot/dolibarr_sellyoursaas/etc/fail2ban/filter.d/email-dolibarr-rulesadmin.conf ]; then
	ln -fs /home/jarvis/wwwroot/dolibarr_sellyoursaas/etc/fail2ban/filter.d/email-dolibarr-rulesadmin.conf
fi
if [ ! -e /home/jarvis/wwwroot/dolibarr_sellyoursaas/etc/fail2ban/filter.d/web-dolibarr-limit403.conf ]; then
	ln -fs /home/jarvis/wwwroot/dolibarr_sellyoursaas/etc/fail2ban/filter.d/web-accesslog-limit403.conf
fi
if [ ! -e /home/jarvis/wwwroot/dolibarr_sellyoursaas/etc/fail2ban/filter.d/web-dolibarr-rulespassforgotten.conf ]; then
	ln -fs /home/jarvis/wwwroot/dolibarr_sellyoursaas/etc/fail2ban/filter.d/web-dolibarr-rulespassforgotten.conf
fi
if [ ! -e /home/jarvis/wwwroot/dolibarr_sellyoursaas/etc/fail2ban/filter.d/web-dolibarr-rulesbruteforce.conf ]; then
	ln -fs /home/jarvis/wwwroot/dolibarr_sellyoursaas/etc/fail2ban/filter.d/web-dolibarr-rulesbruteforce.conf
fi
if [ ! -e /home/jarvis/wwwroot/dolibarr_sellyoursaas/etc/fail2ban/filter.d/web-dolibarr-ruleslimitpublic.conf ]; then
	ln -fs /home/jarvis/wwwroot/dolibarr_sellyoursaas/etc/fail2ban/filter.d/web-dolibarr-ruleslimitpublic.conf
fi
if [ ! -e /home/jarvis/wwwroot/dolibarr_sellyoursaas/etc/fail2ban/filter.d/web-dolibarr-rulesregisterinstance.conf ]; then
	ln -fs /home/jarvis/wwwroot/dolibarr_sellyoursaas/etc/fail2ban/filter.d/web-dolibarr-rulesregisterinstance.conf
fi

# Clean some files
echo "Clean some files"
if [ "x$instanceserver" != "x0" -a "x$instanceserver" != "x" ]; then
	IFS=$(echo -en "\n\b")
	echo We are on a deployment server, so we clean log files 
	echo "Clean web server _error logs"
	for fic in `ls -Adp $targetdir/osu*/dbn*/*_error.log 2>/dev/null | grep -v '/$'`; do > "$fic"; done
	echo "Clean applicative log files"
	for fic in `ls -Adp $targetdir/osu*/dbn*/documents/dolibarr*.log 2>/dev/null | grep -v '/$'`; do > "$fic"; done
	for fic in `ls -Adp $targetdir/osu*/dbn*/htdocs/files/_log/*.log 2>/dev/null | grep -v '/$'`; do > "$fic"; done
	for fic in `ls -Adp $targetdir/osu*/dbn*/htdocs/files/_tmp/* 2>/dev/null | grep -v '/$'`; do rm "$fic"; done
	for fic in `ls -Adp $targetdir/osu*/dbn*/glpi_files/_tmp/* 2>/dev/null | grep -v '/$'`; do rm "$fic"; done
fi

# Disabled: We prefer --prune-empty-dirs
#if [ "x$instanceserver" != "x0" -a "x$instanceserver" != "x" ]; then
#	IFS=$(echo -en "\n\b")
#	echo "We are on a deployment server, so we try to delete empty dirs into backup directory under $backupdir/osu*"
#	find $backupdir/osu*/ -type d -empty -ls -delete > /var/log/find_delete_empty_dir.log 2>&1
#fi

# TODO Try to change permission on this files to remove this ?
touch /var/log/phpmail.log
chown syslog.adm /var/log/phpmail.log
chmod a+rw /var/log/phpmail.log
touch /var/log/phpsendmail.log
chown syslog.adm /var/log/phpsendmail.log
chmod a+rw /var/log/phpsendmail.log

