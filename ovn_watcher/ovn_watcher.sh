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

watcher_validate()
{
	:
}

watcher_monitor()
{
    PID=`pgrep ovn-northd`
    PMEM=`ps --no-headers -o pmem $PID | sed "s/\..*//"`
    if [ $PMEM -gt $OCF_RESKEY_pmem_threshold ]; then
        return $OCF_ERR_GENERIC
    fi

    let "NEEDED_COUNT = $OCF_RESKEY_stable_periods + $OCF_RESKEY_failing_periods + 1"
    printf "%d\n" `ps --no-headers -o vsz $PID` >> /opt/pacemaker_extensions/log/ovn_watcher.log

    COUNT=0
    STABLE_MEM=0
    IS_FAILING=1
    LAST_MEM=0
    tail -n $NEEDED_COUNT /opt/pacemaker_extensions/log/ovn_watcher.log | while read line
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
    if [ $COUNT -eq $NEEDED_COUNT -a $IS_FAILING -eq 0 -a $line -gt $(($STABLE_MEM / $OCF_RESKEY_stable_periods)) ]; then
        return $OCF_ERR_GENERIC
    fi
	return $OCF_SUCCESS
}

watcher_start()
{
	return $OCF_SUCCESS
}


watcher_stop()
{
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
