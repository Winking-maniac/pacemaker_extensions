#! /bin/bash
SLAVE_PATH='/opt/pacemaker_extensions/alerts'
MASTER_PATH='/usr/lib/ocf/resource.d/isp'
CONFIG_DIR='/opt/pacemaker_extensions/config'
DEFAULT_CONFIG="$CONFIG_DIR/telegram_notifier.ini"

INSTALL=1
SETUP=1
FORCE=0

VERBOSITY=0
CONFIG=''
IP=''
PORT=''
PID_DIR='/opt/pacemaker_extensions/pids/telegram_notifier/'
LOG_DIR='/opt/pacemaker_extensions/log'

while [[ $# -gt 0 ]]; do
    case $1 in
        -f)
            FORCE=1
            ;;
        -v)
            let VERBOSITY+=1
            ;;
        -vv)
            let VERBOSITY+=2
            ;;
        -vvv)
            let VERBOSITY+=2
            ;;
        --config)
            CONFIG=$2
            shift
            ;;
        --ip)
            IP=$2
            shift
            ;;
        --port)
            PORT=$2
            shift
            ;;
        --pid-dir)
            PID_DIR=$2
            shift
            ;;
        --log-dir)
            LOG_DIR=$2
            shift
            ;;
        --install-only)
            INSTALL=1
            SETUP=0
            ;;
        --setup-only)
            INSTALL=0
            SETUP=1
            ;;
        --help)
            echo $USAGE
            exit 0
            ;;
        *)
            echo $USAGE
            exit 1
            ;;
    esac
    shift
done

if [ $SETUP -eq 1 ]; then
    #Checking parameters
    if [[ ! $IP =~ ^(([0-9]|[1-9][0-9]|1[0-9][0-9]|2[0-4][0-9]|25[0-5])\.){3}([0-9]|[1-9][0-9]|1[0-9][0-9]|2[0-4][0-9]|25[0-5])$ ]]; then
        echo "Invalid or unspecified IP"
        exit 1
    fi
    if [[ ! $PORT =~ ^([0-9]|[1-9][0-9]|[1-9][0-9][0-9]|[1-9][0-9][0-9][0-9]|[1-5][0-9]{4}|6[0-4][0-9]{3}|65[0-4][0-9]{2}|655[0-2][0-9]|6553[0-5])$ ]]; then
        echo "Invalid or unspecified port"
        exit 1
    fi

    if [ -z  $CONFIG]; then
        if [ ! -f $CONFIG ]; then
            echo 'Provided config not found'
            exit 1
        fi
    fi
fi

# Setup
pcs status >/dev/null 2>&1
if [ $? -ne 0 ]; then
    echo "Pacemaker is not running (try to start script with sudo)"
    exit 1
fi

# Assume we have root privileges

if [ $INSTALL -eq 1 ]; then
    # Master install
    mkdir -p $MASTER_PATH >/dev/null 2>&1
    if [ $? -ne 0 ]; then
        echo 'Cannot create master directory'
        exit 1
    fi
    if [ $VERBOSITY -gt 1 ]; then
        echo "Master path created"
    fi
    chown hacluster $MASTER_PATH >/dev/null 2>&1
    cp ./telegram_notifier_master.sh $MASTER_PATH/telegram_notifier_master >/dev/null 2>&1
    if [ $? -ne 0 ]; then
        echo 'Cannot create master agent'
        exit 1
    fi
    chown hacluster $MASTER_PATH/telegram_notifier_master >/dev/null 2>&1
    if [ $VERBOSITY -gt 0 ]; then
        echo "Master agent installed"
    fi

    # Slave install
    mkdir -p $SLAVE_PATH >/dev/null 2>&1
    if [ $? -ne 0 ]; then
        echo 'Cannot create slave directory'
        exit 1
    fi
    if [ $VERBOSITY -gt 1 ]; then
        echo "Slave path created"
    fi
    chown hacluster $SLAVE_PATH >/dev/null 2>&1
    cp ./telegram_notifier_slave.sh $SLAVE_PATH/telegram_notifier_slave >/dev/null 2>&1
    if [ $? -ne 0 ]; then
        echo 'Cannot create slave agent'
        exit 1
    fi
    chown hacluster $SLAVE_PATH/telegram_notifier_slave >/dev/null 2>&1
    if [ $VERBOSITY -gt 1 ]; then
        echo "Slave agent installed"
    fi

    # Master main server install
    cp ./telegram_notifier_master.py $SLAVE_PATH/telegram_notifier_master.py >/dev/null 2>&1
    if [ $? -ne 0 ]; then
        echo 'Cannot create master main server file'
        exit 1
    fi
    chown hacluster $SLAVE_PATH/telegram_notifier_master.py >/dev/null 2>&1
    if [ $VERBOSITY -gt 0 ]; then
        echo "Master installed"
    fi
fi

if [ $SETUP -eq 1 ]; then
    if [ $VERBOSITY -gt 0 ]; then
        echo "Started configuring"
    fi
    # Making log dir
    mkdir -p $LOG_DIR >/dev/null 2>&1
    if [ $? -ne 0 ]; then
        echo 'Cannot create log directory'
        exit 1
    fi
    if [ $VERBOSITY -gt 1 ]; then
        echo "Log directory created"
    fi
    chown hacluster $LOG_DIR >/dev/null 2>&1

    # Making pid dir
    mkdir -p $PID_DIR >/dev/null 2>&1
    if [ $? -ne 0 ]; then
        echo 'Cannot create pid directory'
        exit 1
    fi
    if [ $VERBOSITY -gt 1 ]; then
        echo "Pid directory created"
    fi
    chown hacluster $PID_DIR >/dev/null 2>&1

    # Creating config
    if [ -z $CONFIG ]; then
        echo "Creating config in default directory: $CONFIG_DIR"
        # Making config directory
        mkdir -p $CONFIG_DIR >/dev/null 2>&1
        if [ $? -ne 0 ]; then
            echo 'Cannot create config directory'
            exit 1
        fi
        if [ $VERBOSITY -gt 1 ]; then
            echo "Config directory created"
        fi
        if [ -e $DEFAULT_CONFIG -a $FORCE -eq 0 ]; then
            echo "Cannot create config by default path: file exists. Make config by yourself and provide it via --config or remove $CONFIG_DIR/telegram_notifier.ini and try again"
            exit 1
        fi
        rm $DEFAULT_CONFIG >/dev/null 2>&1
        touch $DEFAULT_CONFIG >/dev/null 2>&1
        chmod 660 $DEFAULT_CONFIG >/dev/null 2>&1
        if [ $? -ne 0 ]; then
            echo 'Cannot create config'
        fi

        if [ $VERBOSITY -gt 1 ]; then
            echo "Config file created"
        fi

        # Reading cloud name
        while [ -z $LINE ]; do
            read -p "Cloud name: " LINE
        done
        printf '[General]\nCloud = %s\n' $LINE > $DEFAULT_CONFIG
        LINE=''

        # Reading URL
        while [ -z $LINE ]; do
            read -p "Bot send message URL: " LINE
        done
        printf 'URL = %s\n' $LINE >> $DEFAULT_CONFIG
        LINE=''

        # Reading check interval
        while [ -z $LINE ]; do
            read -p "Cluster check interval(e.g '1d 1h 1m 1s'):" LINE
        done
        printf 'cluster_check_interval = %s\n' $LINE >> $DEFAULT_CONFIG
        LINE=''

        # Adding already known parameters
        printf 'loglevel = 10\n' >> $DEFAULT_CONFIG
        printf 'log = %s\n' $LOG_DIR/telegram_notifier.log >> $DEFAULT_CONFIG
        printf 'IP = %s\n' $IP >> $DEFAULT_CONFIG
        printf 'port = %s\n' $PORT >> $DEFAULT_CONFIG

        # Adding recipients
        echo "Adding recipients. Stop by Ctrl-D"


        while read -p "Recipient name: " LINE; do
            if [ -z $LINE ]; then
                break
            fi
            read -p "Recipient telegram ID: " TG_ID
            if [ -z $TG_ID ]; then
                break
            fi

            printf '[%s]\ntelegram_id = %s\n' $LINE $TG_ID >> $DEFAULT_CONFIG
            LINE=''
            TG_ID=''
            # printf "Recipient name:"
            # read LINE
        done
        printf "\n\nYou can edit config at any time manually, for example, add new recepients. Don't forget to restart tg_notifier after config editing\n\n"

        if [ $VERBOSITY -gt 0 ]; then
            echo "Configuration complete"
        fi
        CONFIG=$DEFAULT_CONFIG
    else
        if [ $VERBOSITY -gt 0 ]; then
            echo "Using provided config"
        fi
    fi

    # Configuring Pacemaker
    if [ $VERBOSITY -gt 0 ]; then
        echo "Adding notifier to Pacemaker resources"
    fi

    # Virtual IP
    pcs resource create tg_ip ocf:heartbeat:IPaddr2 ip=$IP cidr_netmask=32
    if [ $? -ne 0 ]; then
        echo 'Cannot create virtual IP in Pacemaker'
        exit 1
    fi
    if [ $VERBOSITY -gt 1 ]; then
        echo "Virtual IP created"
    fi

    # Slave configuring
    pcs alert create path=$SLAVE_PATH/telegram_notifier_slave id=tg_notifier_slave \
            description='Notifier slave for telegram notifier(check ocf:isp:telegram_notifier for further information)'
    if [ $? -ne 0 ]; then
        echo 'Cannot create slave agent in Pacemaker'
        exit 1
    fi

    pcs alert recipient add tg_notifier_slave value="$IP $PORT" id=master
    if [ $? -ne 0 ]; then
        echo 'Cannot link slave and master agents in Pacemaker'
        exit 1
    fi
    if [ $VERBOSITY -gt 1 ]; then
        echo "Slave agent created"
    fi

    # Master configuring
    pcs resource create tg_notifier_master ocf:isp:telegram_notifier_master script=$SLAVE_PATH/telegram_notifier_master.py config=$CONFIG piddir=$PID_DIR
    if [ $? -ne 0 ]; then
        echo 'Cannot create master agent in Pacemaker'
        exit 1
    fi

    pcs resource group add tg_notifier tg_ip tg_notifier_master
    if [ $? -ne 0 ]; then
        echo 'Cannot group IP and master agents in Pacemaker'
        exit 1
    fi
    if [ $VERBOSITY -gt 1 ]; then
        echo "Master agent created"
    fi
    if [ $VERBOSITY -gt 0 ]; then
        echo "Installation successful"
    fi
fi
