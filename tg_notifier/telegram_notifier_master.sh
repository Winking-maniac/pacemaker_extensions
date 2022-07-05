#!/bin/sh
#
# Resource script for Telegram notifier
#
# Description:  Manages main Telegram notifier server
#
# Script Author: Winking_maniac
# License: GNU General Public License (GPL)
#
#
#	usage: $0 {start|stop|monitor|validate-all|meta-data}
#
#	The "start" arg starts main server.
#
#	The "stop" arg stops it.
#
# OCF parameters:
# OCF_RESKEY_script
# OCF_RESKEY_config
# OCF_RESKEY_piddir
#
##########################################################################
# Initialization:

: ${OCF_FUNCTIONS_DIR=${OCF_ROOT}/resource.d/heartbeat}
. ${OCF_FUNCTIONS_DIR}/.ocf-shellfuncs

USAGE="Usage: $0 {start|stop|monitor|validate-all|meta-data}";
PIDDIR="/"
##########################################################################

usage()
{
	echo $USAGE >&2
}

meta_data()
{
cat <<END
<?xml version="1.0"?>
<!DOCTYPE resource-agent SYSTEM "ra-api-1.dtd">
<resource-agent name="Telegram-notifier">
<version>1.0</version>

<longdesc lang="en">
This script manages Telegram notifier main server
</longdesc>
<shortdesc lang="en">Manages the Telegram notifier</shortdesc>
<parameters>
<parameter name="script" unique="1">
<longdesc lang="en">
The full path to the script
By default, "/opt/pacemaker_extensions/alerts/telegram_admin_alert.py" will be run
</longdesc>
<shortdesc lang="en">Name of the script we will be executing</shortdesc>
<content type="string" default="/opt/pacemaker_extensions/alerts/telegram_admin_alert.py"/>
</parameter>
<parameter name="config">
<longdesc lang="en">
The full path to the config file
By default, "/opt/pacemaker_extensions/config/telegram_admin_alert.ini" will be used
</longdesc>
<shortdesc lang="en">Parameters for the script</shortdesc>
<content type="string" default="/opt/pacemaker_extensions/config/telegram_admin_alert.ini"/>
</parameter>
<parameter name="piddir">
<longdesc lang="en">
The full path to the directory to store pidfile
By default, "/opt/pacemaker_extensions/pids/telegram_notifier/" will be used
</longdesc>
<shortdesc lang="en">Directory for PID storing</shortdesc>
<content type="string" default="/opt/pacemaker_extensions/pids/telegram_notifier/"/>
</parameter>
</parameters>
<actions>
<action name="start" timeout="20s"/>
<action name="stop" timeout="20s"/>
<action name="monitor" timeout="20s" interval="60s" />
<action name="validate-all" timeout="20s"/>
<action name="meta-data"  timeout="5s"/>
</actions>
</resource-agent>
END
exit $OCF_SUCCESS
}

tg_notifier_validate()
{
    $SCRIPT check $CONFIG
    if [ $? -eq 1 ]; then
        exit $OCF_ERR_ARGS
    fi
}

tg_notifier_monitor()
{
	if [ -e "$PIDDIR/pid" ]; then
        PID=`cat $PIDDIR/pid`
        if [ -z `ps --no-headers $PID` ]; then
            ocf_rm_pid $PIDIR
        	return $OCF_NOT_RUNNING
        else
            return $OCF_SUCCESS
        fi
    fi
	if false ; then
		return $OCF_ERR_GENERIC
	fi
	return $OCF_NOT_RUNNING
}

tg_notifier_start()
{
	if [ ! -x "$SCRIPT" ]; then
		ocf_log err "Script is not executable."
		exit $OCF_ERR_GENERIC
	fi

	tg_notifier_monitor
	retVal=$?
	if [ $retVal -eq $OCF_NOT_RUNNING ]; then
        ($SCRIPT $CONFIG $PIDDIR)&
        tg_notifier_monitor
        while [ $? -eq $OCF_NOT_RUNNING ]
        do
            sleep 1
            tg_notifier_monitor
        done
        exit $OCF_SUCCESS
    elif [ $retVal -eq $OCF_SUCCESS ]; then
        exit $OCF_SUCCESS
    else
        ocf_log err "Telegram notifier is neither running nor stopped"
        exit $OCF_ERR_GENERIC
	fi
}


tg_notifier_stop()
{
	# check if the script is there
	if [ ! -x "$SCRIPT" ]; then
		ocf_log err "Script is not executable."
		exit $OCF_ERR_GENERIC
	fi

    tg_notifier_monitor
	retVal=$?
	if [ $retVal -eq $OCF_SUCCESS ]; then
		kill -TERM $PID
        while [1]
        do
            sleep 0.5
            if [ -z `ps --no-headers $PID` ]; then
                ocf_rm_pid $PIDDIR
                exit $OCF_SUCCESS
            fi
        done
	elif [ $retVal -eq $OCF_NOT_RUNNING ]; then
		exit $OCF_SUCCESS
	else
		ocf_log err "Telegram notifier is neither running nor stopped"
		exit $OCF_ERR_GENERIC
	fi

}

#
# Main
#

if [ $# -ne 1 ]; then
	usage
	exit $OCF_ERR_ARGS
fi

if [ -n "$OCF_RESKEY_script" ]; then
    SCRIPT=${OCF_RESKEY_script}
else
    ocf_log info "Using default script name"
    SCRIPT="/opt/pacemaker_extensions/alerts/telegram_admin_alert.py"
fi

if [ -n "$OCF_RESKEY_config" ]; then
    CONFIG=${OCF_RESKEY_config}
else
    ocf_log info "Using default config name"
    CONFIG="/opt/pacemaker_extensions/config/telegram_admin_alert.ini"
fi

if [ -n "$OCF_RESKEY_piddir" ]; then
    PIDDIR=${OCF_RESKEY_piddir}
else
    ocf_log info "Using default piddir"
    PIDDIR="/opt/pacemaker_extensions/pids/telegram_notifier/"
fi


case $__OCF_ACTION in
	start)
        tg_notifier_validate
        tg_notifier_start
		;;

	stop)
		tg_notifier_stop
		;;

	monitor)
		tg_notifier_monitor
		;;

	validate-all)
        tg_notifier_validate
		;;

	meta-data)
        meta_data
		;;

	usage)	usage
		exit $OCF_SUCCESS
		;;

	*)	usage
		exit $OCF_ERR_UNIMPLEMENTED
		;;
esac

exit $!
