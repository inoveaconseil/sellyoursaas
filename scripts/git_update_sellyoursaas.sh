#!/bin/bash
#---------------------------------------------------------
# Script to update programs for Dolibarr and sell-your-saas
#
# To include into cron
# /pathto/git_update_sellyoursaas.sh /home/jarvis/wwwroot > /pathto/git_update_sellyoursaas.log 2>&
#---------------------------------------------------------

source /etc/lsb-release

if [ "x$1" == "x" ]; then
   echo "Usage:   $0  dir_of_git_repositories_of_app"
   echo "Example: $0  /home/jarvis/wwwroot"
   exit 1
fi

if [ "$(id -u)" == "0" ]; then
   echo "This script must be run as admin, not as root" 1>&2
   exit 1
fi

error=0


# Get domain of the GIT server with sources
export gitserver=`grep '^gitserver=' /etc/sellyoursaas.conf | cut -d '=' -f 2`
if [[ "x$gitserver" == "x" ]]; then
	export gitserver="github.com"
fi
gitserver=${gitserver//[^a-zA-Z0-9.]/}

# Install fingerprint of github.com but only if it was never installed
# If it is already present, we keep it so we will be protected if domain name is routed on another evil server
# TODO Allow to choose the git domain name server in /etc/sellyousaas.conf 
echo "Install the known fingerprint of github if it was never installed"
ssh-keygen -F "$gitserver" || ssh-keyscan "$gitserver" >>~/.ssh/known_hosts


echo "Update git dirs found into $1."

for dir in `ls -d $1/dolibarr* | grep -v documents`
do
	# If a subdir is given, discard if not subdir
	#if [ "x$2" != "x" ]; then
	#	if [ "x$1/$2" != "x$dir" ]; then
	#		continue;
	#	fi
	#fi

    echo -- Process dir $dir
    cd $dir
	if [ $? -eq 0 ]; then
		export gitdir=`basename $dir`
		
	    if [ -d ".git" ]; then
	    	echo chmod -R u+w $dir
	    	chmod -R u+w $dir
	    	git pull
	    	if [ $? -ne 0 ]; then
	    		# If git pull fail, we force a git reset before and try again.
	        	echo Execute a git reset --hard HEAD
	        	git reset --hard HEAD
	        	# Do not use git pull --depth=1 here, this will make merge errors.
	        	git pull
	        	if [ $? -ne 0 ]; then
	        		export error=1
	        	fi
	        fi
	        echo Result of git pull = $?

	    	git rev-parse HEAD > gitcommit.txt
	    else
	        echo "Not a git dir. Nothing done."
	    fi
		
	    cd -
	fi
done

echo "Finished (exit=$error)."
exit $error

