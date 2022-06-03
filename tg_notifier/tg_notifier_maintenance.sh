#!/bin/bash

ACTION=""
KEEP_YOURSELF='false'
MESSAGE=""
NAME="Anonymous admin"
USAGE="usage: tg_notify_maintenance --start|--stop [--name *name*] [--message *message*]"

while [[ $# -gt 0 ]]; do
    case $1 in
        --start)
            if [ -z $ACTION ]; then
                ACTION="start"
            else
                echo $USAGE
                exit 1
            fi
            ;;
        --stop)
            if [ -z $ACTION ]; then
                ACTION="stop"
            else
                echo $USAGE
                exit 1
            fi
            ;;
        --message)
            MESSAGE=$2
            shift
            ;;
        --name)
            NAME=$2
            shift
            ;;
        *)
            echo $USAGE
            exit 1
            ;;
    esac
    shift
done

if [ -z $ACTION ]; then
    echo $USAGE
    exit 1
fi

PIDDIR=`sudo pcs resource config tg_notifier | gawk  'match($0, /piddir=([^ ]*)/, ary) {print ary[1]}'`
if [ -z $PIDDIR ]; then
    PIDDIR="/opt/pacemaker_extensions/pids/telegram_notifier/"
fi

if [ $ACTION == 'start' ]; then
    printf "%s\n%s" $NAME $MESSAGE > $PIDDIR/maintenance
fi

if [ $ACTION == 'stop' ]; then
    rm -f $PIDDIR/maintenance
fi

kill -USR1 `cat $PIDDIR/pid`
