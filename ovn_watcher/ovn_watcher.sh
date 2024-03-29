#!/bin/sh
#
# Ovn memory usage watcher
#
# Description:  Watches ovn-northd memory usage and fails if it becomes too high
#
# Script Author: Winking_maniac
# License: GNU General Public License (GPL)
#
#
#	usage: $0 {start|stop|monitor|validate-all|meta-data}
#
#	The "start" and "stop" args do nothing except that Pacemaker doesn't execute monitor operation.
#
#
# OCF parameters:
# OCF_RESKEY_pmem_threshold
# OCF_RESKEY_failing_periods
# OCF_RESKEY_stable_periods
#
##########################################################################
# Initialization:
: ${OCF_FUNCTIONS_DIR=${OCF_ROOT}/resource.d/heartbeat}
. ${OCF_FUNCTIONS_DIR}/.ocf-shellfuncs

USAGE="Usage: $0 {start|stop|monitor|validate-all|meta-data}";
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
<resource-agent name="ovn-watcher">
<version>1.0</version>
<longdesc lang="en">
Watches ovn-northd memory usage and fails if it becomes too high
</longdesc>
<shortdesc lang="en">Watches ovn-northd memory usage</shortdesc>
<parameters>
<parameter name="pmem_threshold" unique="1">
<longdesc lang="en">
Percent of memory used by northd on which agent fails
By default, 20
</longdesc>
<shortdesc lang="en">Name of the script we will be executing</shortdesc>
<content type="integer" default="20"/>
</parameter>
<parameter name="failing_periods" unique="1">
<longdesc lang="en">
Periods used for checking whether ovn-northd failed.
By default, 3
</longdesc>
<shortdesc lang="en">Periods used for checking whether ovn-northd failed </shortdesc>
<content type="integer" default="3"/>
</parameter>
<parameter name="stable_periods" unique="1">
<longdesc lang="en">
Periods used for calculating average northd memory usage.
By default, 5
</longdesc>
<shortdesc lang="en">Periods used for calculating average northd memory usage</shortdesc>
<content type="integer" default="5"/>
</parameter>
</parameters>
<actions>
<action name="start" timeout="20s"/>
<action name="stop" timeout="20s"/>
<action name="monitor" timeout="20s" interval="3600s" />
<action name="validate-all" timeout="20s"/>
<action name="meta-data"  timeout="5s"/>
</actions>
</resource-agent>
END
exit $OCF_SUCCESS
}

if [ -z $OCF_RESKEY_pmem_threshold ]; then
    OCF_RESKEY_pmem_threshold="20"
fi


if [ -z $OCF_RESKEY_failing_periods ]; then
    OCF_RESKEY_failing_periods="3"
fi


if [ -z $OCF_RESKEY_stable_periods ]; then
    OCF_RESKEY_stable_periods="5"
fi


watcher_validate()
{
	:
}

watcher_monitor()
{
    if ! [ -e /opt/pacemaker_extensions/ovn_watcher/active ]; then
        exit $OCF_NOT_RUNNING
    fi
    cat /opt/pacemaker_extensions/ovn_watcher/active | read CUR_HOURS_WORKING
    if [ -z $CUR_HOURS_WORKING ]; then
	CUR_HOURS_WORKING=0
    fi
    printf "%d" $(( CUR_HOURS_WORKING + 1 )) >> /opt/pacemaker_extensions/ovn_watcher/active  
    PID=`pgrep ovn-northd`
    PMEM=`ps --no-headers -o pmem $PID | sed "s/\..*//"`
    if [ $PMEM -gt $OCF_RESKEY_pmem_threshold ]; then
        return $OCF_ERR_GENERIC
    fi

    let "NEEDED_COUNT = $OCF_RESKEY_stable_periods + $OCF_RESKEY_failing_periods + 1"
    if [ $NEEDED_COUNT -gt $CUR_HOURS_WORKING ]; then
        $READ_COUNT=$CUR_HOURS_WORKING
    else
        $READ_COUNT=$NEEDED_COUNT
    fi
    printf "%s    %d\n" "`date +"%F %R:%S"`" `ps --no-headers -o vsz $PID` >> /opt/pacemaker_extensions/log/ovn_watcher.log

    COUNT=0
    STABLE_MEM=0
    IS_FAILING=1
    LAST_MEM=0
    tail -n $READ_COUNT /opt/pacemaker_extensions/log/ovn_watcher.log | while read useless1 useless2 line
    do
        if [ $COUNT -lt $OCF_RESKEY_stable_periods ]; then
            let "STABLE_MEM = $STABLE_MEM + $line"
            LAST_MEM=$line
        else
            if [ $LAST_MEM -gt $line ]; then
                IS_FAILING=0
            fi
        fi
        COUNT=$(( $COUNT + 1 ))
    done
    if [ $COUNT -eq $NEEDED_COUNT -a $IS_FAILING -eq 1 -a $($line * $OCF_RESKEY_stable_periods * 100) -gt $(($STABLE_MEM * 120)) ]; then
        return $OCF_ERR_GENERIC
    fi
	return $OCF_SUCCESS
}

watcher_start()
{
    touch /opt/pacemaker_extensions/ovn_watcher/active
	return $OCF_SUCCESS
}


watcher_stop()
{
    rm /opt/pacemaker_extensions/ovn_watcher/active
	return $OCF_SUCCESS
}

#
# Main
#

if [ $# -ne 1 ]; then
	usage
	exit $OCF_ERR_ARGS
fi


case $__OCF_ACTION in
	start)
        watcher_start
		;;

	stop)
		watcher_stop
		;;

	monitor)
		watcher_monitor
		;;

	validate-all)
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
