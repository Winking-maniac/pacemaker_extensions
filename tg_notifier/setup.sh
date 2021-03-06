#! /bin/bash
# SLAVE_PATH='/opt/pacemaker_extensions/alerts'
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

SCRIPT_DIR="$( cd -- "$( dirname -- "${BASH_SOURCE[0]:-$0}"; )" &> /dev/null && pwd 2> /dev/null; )";

log(){
    if [ $VERBOSITY -gt $1 ]; then
        i=0
        while [ $i -lt $1 ]; do
            printf "\t"
            let "i=$i + 1"
        done
        if [ $1 -eq 0 ]; then
            echo -en "\033[32;1m[\u2714]\033[0m "
        fi
        echo $2
    fi
}

error() {
    echo -en "\033[31;1m[\u2718] "
    echo -n $1
    echo -e "\033[0m"
    exit 1
}

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
        error "Invalid or unspecified IP"
    fi
    if [[ ! $PORT =~ ^([0-9]|[1-9][0-9]|[1-9][0-9][0-9]|[1-9][0-9][0-9][0-9]|[1-5][0-9]{4}|6[0-4][0-9]{3}|65[0-4][0-9]{2}|655[0-2][0-9]|6553[0-5])$ ]]; then
        error "Invalid or unspecified port"
    fi

    if [ -z  $CONFIG ]; then
        if [ ! -f $CONFIG ]; then
            error 'Provided config not found'
        fi
    fi
fi

# Setup
pcs status >/dev/null 2>&1
if [ $? -ne 0 ]; then
    error "Pacemaker is not running (try to start script with sudo)"
fi

# Assume we have root privileges

if [ $INSTALL -eq 1 ]; then
    log 0 "Installation started"
    # Master install
    mkdir -p $MASTER_PATH >/dev/null 2>&1
    if [ $? -ne 0 ]; then
        error 'Cannot create master directory'
    fi

    log 1 "Master path created"

    chown hacluster $MASTER_PATH >/dev/null 2>&1
    cp ./telegram_notifier_master.sh $MASTER_PATH/telegram_notifier_master >/dev/null 2>&1
    if [ $? -ne 0 ]; then
        error 'Cannot create master agent'
    fi
    chown hacluster $MASTER_PATH/telegram_notifier_master >/dev/null 2>&1
    chmod 755 $MASTER_PATH/telegram_notifier_master >/dev/null 2>&1

    cp ./tg_notifier_maintenance.sh /usr/local/bin/notifier-maintenance
    chmod 755 /usr/local/bin/notifier-maintenance

    log 0 "Maintenance script installed"
    # Slave install
    # mkdir -p $SLAVE_PATH >/dev/null 2>&1
    # if [ $? -ne 0 ]; then
    #     echo 'Cannot create slave directory'
    #     exit 1
    # fi
    # log 1 "Slave path created"
    #
    # chown hacluster $SLAVE_PATH >/dev/null 2>&1
    # cp ./telegram_notifier_slave.sh $SLAVE_PATH/telegram_notifier_slave >/dev/null 2>&1
    # if [ $? -ne 0 ]; then
    #     echo 'Cannot create slave agent'
    #     exit 1
    # fi
    # chown hacluster $SLAVE_PATH/telegram_notifier_slave >/dev/null 2>&1
    # log 0 "Slave agent installed"
    #
    # # Master main server install
    # cp ./telegram_notifier_master.py $SLAVE_PATH/telegram_notifier_master.py >/dev/null 2>&1
    # if [ $? -ne 0 ]; then
    #     echo 'Cannot create master main server file'
    #     exit 1
    # fi
    # chown hacluster $SLAVE_PATH/telegram_notifier_master.py >/dev/null 2>&1
    log 0 "Installation complete"
    echo ""
fi

if [ $SETUP -eq 1 ]; then
    log 0 "Started configuring"

    # Making log dir
    mkdir -p $LOG_DIR >/dev/null 2>&1
    if [ $? -ne 0 ]; then
        error 'Cannot create log directory'
    fi
    log 1 "Log directory created"

    # chown hacluster $LOG_DIR >/dev/null 2>&1

    # Making pid dir
    mkdir -p $PID_DIR >/dev/null 2>&1
    if [ $? -ne 0 ]; then
        error 'Cannot create pid directory'
    fi
    log 1 "Pid directory created"

    # chown hacluster $PID_DIR >/dev/null 2>&1

    # Creating config
    if [ -z $CONFIG ]; then
        echo "Creating config in default directory: $CONFIG_DIR"
        # Making config directory
        mkdir -p $CONFIG_DIR >/dev/null 2>&1
        if [ $? -ne 0 ]; then
            error 'Cannot create config directory'
        fi
        log 1 "Config directory created"

        if [ -e $DEFAULT_CONFIG -a $FORCE -eq 0 ]; then
            error "Cannot create config by default path: file exists. Make config by yourself and provide it via --config or remove $CONFIG_DIR/telegram_notifier.ini and try again"
        fi
        rm $DEFAULT_CONFIG >/dev/null 2>&1
        touch $DEFAULT_CONFIG >/dev/null 2>&1
        if [ $? -ne 0 ]; then
            error 'Cannot create config'
        fi
        chmod 660 $DEFAULT_CONFIG >/dev/null 2>&1

        log 1 "Config file created"

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

        log 0 "Configuration complete"

        CONFIG=$DEFAULT_CONFIG
    else
        log 0 "Using provided config"
    fi

    # Configuring Pacemaker
    log 0 "Adding notifier to Pacemaker resources"

    # Virtual IP
    pcs resource create tg_ip ocf:heartbeat:IPaddr2 ip=$IP cidr_netmask=32 --disabled
    if [ $? -ne 0 ]; then
        error 'Cannot create virtual IP in Pacemaker'
    fi
    log 1 "Virtual IP created"

    # Slave configuring
    pcs alert create path=./telegram_notifier_slave.sh id=tg_notifier_slave \
            description='Notifier slave for telegram notifier(check ocf:isp:telegram_notifier for further information)'
    if [ $? -ne 0 ]; then
        error 'Cannot create slave agent in Pacemaker'
    fi

    pcs alert recipient add tg_notifier_slave value="$IP $PORT" id=master
    if [ $? -ne 0 ]; then
        error 'Cannot link slave and master agents in Pacemaker'
    fi
    log 1 "Slave agent created"

    # Master configuring
    pcs resource create tg_notifier_master ocf:isp:telegram_notifier_master script=$SCRIPT_DIR/telegram_notifier_master.py config=$CONFIG piddir=$PID_DIR --disabled
    if [ $? -ne 0 ]; then
        error 'Cannot create master agent in Pacemaker'
    fi

    pcs resource group add tg_notifier tg_ip tg_notifier_master
    if [ $? -ne 0 ]; then
        error 'Cannot group IP and master agents in Pacemaker'
    fi
    log 1 "Master agent created"

    pcs resource enable tg_ip
    pcs resource enable tg_notifier_master    
    log 0 "Configuration successful"
fi
