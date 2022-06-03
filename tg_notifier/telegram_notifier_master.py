#!/bin/python3
import configparser
import sys
import os
import subprocess
import socket
import signal
import logging
import traceback

#config_path = "telegram_admin_alert.ini"
is_serving = False
sock = None
maintenance = False
#validate_log = logging.getLogger()
#validate_log.setLevel(logging.DEBUG)

#validate_hdlr = logging.StreamHandler(sys.stderr)
#validate_hdlr.setLevel(logging.DEBUG)
#validate_log.addHandler(validate_hdlr)

def check_config(config_path):
    """
    Checks config file stores at 'config_path' to be full and correct configuration file for this script

    Example of correct config:

    [General]
    Cloud = TEST
    URL = https://api.telegram.org/bot863813709:AAGCWOY5n2o8aWeoMWSabi5QeLPcX7jCL1M/sendMessage
    IP = 127.0.0.1
    port = 5555
    log = /opt/pacemaker_extensions/logs/telegram_notifier.log
    loglevel = logging.DEBUG

    [Winking_maniac]
        telegram_id = 578240866
    [varenie_vs]
        telegram_id = 123456789
    """
    try:
        config = configparser.ConfigParser()
        config.read(config_path)
    except:
        validate_log.debug("config is not availible")
    #validate_log.debug("config found")
    config_correct = True
    config_correct = config_correct and ("General" in config)
    #validate_log.debug("general section found")
    if not config_correct:
        exit(1)
    config_correct = config_correct and ("log" in config["General"])
    config_correct = config_correct and ("loglevel" in config["General"])
    config_correct = config_correct and ("IP" in config["General"])
    config_correct = config_correct and ("port" in config["General"])
    config_correct = config_correct and ("URL" in config["General"])
    config_correct = config_correct and ("Cloud" in config["General"])
    config_correct = config_correct and ("cluster_check_interval" in config["General"])
    if not config_correct:
        exit(1)
    #if config_correct:
    #validate_log.debug("General includes all we need")
    for recipient in config.sections():
        if recipient != "General":
            config_correct = config_correct and ("telegram_id" in config[recipient])

    logging.basicConfig(filename=config["General"]["log"],level=config["General"].getint("loglevel"))
    logging.debug(f"Config is valid - {config_correct}")
    if not config_correct:
        exit(1)

def parse_time(time_str):
    """
    Transforms time interval from string formatted as '1d 1h 1m 1s' to seconds

    Args:
        time_str -- string with human-readable time interval
    Return value: integer, interval in seconds
    Examples:   1d 1h 1m 1s -> 90061
                1d          -> 84600
                1h          -> 3600
                1m          -> 60
                1s          -> 1
    """
    cur_state = 'd'
    cnt = 0
    res = 0
    for c in time_str:
        if c.isspace():
            continue
        if c.isdigit():
            cnt = 10 * cnt + int(c)
        elif c == 'd':
            if cur_state != 'd':
                raise ValueError('Not a valid date')
            cur_state = 'h'
            res += 24 * 60 * 60 * cnt
            cnt = 0
        elif c == 'h':
            if cur_state != 'd' and cur_state != 'h' :
                raise ValueError('Not a valid date')
            cur_state = 'm'
            res += 60 * 60 * cnt
            cnt = 0
        elif c == 'm':
            if cur_state == 's':
                raise ValueError('Not a valid date')
            cur_state = 's'
            res += 60 * cnt
            cnt = 0
            cnt = 0
        elif c == 's':
            res += cnt
            return res
        else:
            raise ValueError('Not a valid date')
    return res

def get_events(conn):
    """
    Extracts data from connection

    Args:
        conn -- connection from which extract data
    Return value: string with data from the conn
    """
    logging.debug("get_events")
    cur_data = b''
    with conn:
        while True:
            data = conn.recv(1024)
            if not data: break
            cur_data += data
        if check_msg(cur_data.decode('utf-8')):
            return cur_data.decode('utf-8') + '\n'
        else:
            return ""

def check_msg(msg):
    """
    Checks message signature to verify if message from our slave-notifier
    If yes, checks whether message is important
    """
    logging.debug("check_msg")
    msg_types = {"node":2,
                "fencing":1,
                "resource":6}

    msg_arr = msg.split(';')

    if len(msg_arr) < 2 or msg_arr[1] not in msg_types:
        return False
    if len(msg_arr) != msg_types[msg_arr[1]] + 3:
        return False
    if msg_arr[1] == "node":
        return True
    elif msg_arr[1] == "fencing":
        return False
    elif msg_arr[1] == "resource":
        if msg_arr[6] not in [0, 7, 8]:
            return True
        else:
            return False
    return True

def describe(events):
    """
    Print human-readable error description
    """
    return events

def serve(ip, port, piddir):
    """
    Main serving function. Implement nearly all notifier logic.
    Sends messages to recipients about:
    1) Start of activity in cluster and its reason
    2) End of activity in cluster and the final state of cluster
    3) Start/stop of notifier working

    Args:
        ip -- string with ip to listen
        port -- integer port to listen
    """
    logging.debug("serve")
    global is_serving
    global sock
    is_serving = True

    cloud_active_state = False
    cloud_check_interval = parse_time(config["General"]["cluster_check_interval"])

    sock = socket.socket()
    logging.debug("before binding")
    sock.bind((ip, port))
    logging.debug("binding successful")
    sock.listen()

    send_start_message()
    save_pid = [[f'mkdir {piddir} 2>/dev/null'], [f'echo {os.getpid()} > {piddir}/pid']]
    logging.debug(str(save_pid))
    subprocess.run(save_pid[0], shell=True)
    subprocess.run(save_pid[1], shell=True)
    try:
        while is_serving:
            sock.setblocking(True)
            conn, address = sock.accept()
            cur_events = ""
            cur_events += get_events(conn)
            if not cur_events:
                continue
            send_cloud_active_message(reason_event=describe(cur_events))
            sock.settimeout(cloud_check_interval)
            while True:
                try:
                    conn, address = sock.accept()
                    cur_events += get_events(conn)
                except socket.timeout:
                    send_cloud_stable_message()
                    if "send_stable_more_info" in config["General"] and \
                            config["General"].getboolean("send_stable_more_info"):
                        send(message="More events info:\n" + describe(cur_events), tag='more')
                    break
    except OSError as e:
        logging.debug(e.__traceback__)
        if e.errno != 9: # Catching socket.close
            raise
    except Exception as e:
        logging.debug(traceback.format_exc())
        raise
    send_stop_message()

def send_status():
    status = subprocess.run(["pcs", "status"], stdout=subprocess.PIPE, shell=True, encoding='ascii').stdout.split('Failed Resource Actions')[0].split('\n')
    cur_msg = ""
    for line in status:
        if len(cur_msg) + len(line) + 1 < 4000:
            cur_msg += line + '\n'
        else:
            send(message=f'`{cur_msg}`')
            cur_msg = ""
    if len(cur_msg) != 0:
        send(message=f'`{cur_msg}`', tag='status')

def send_start_message():
    send(message=f'{config["General"]["Cloud"]}: notifier started')
    send_status()

def send_stop_message():
    send(message=f'{config["General"]["Cloud"]}: notifier stopped')

def send_cloud_still_active_message():
    send(message=f'{config["General"]["Cloud"]}: still unstable')

def send_cloud_active_message(reason_event):
    send(message=f'{config["General"]["Cloud"]}: fail. Overcoming actions started\n\nReason: `{reason_event}`')

def send_cloud_stable_message():
    send(message=f'{config["General"]["Cloud"]}: fail has been overcome\n\n')
    send_status()

def send_maintenance_msg(type, name="", message=""):
    if type == 'start':
        send(message=f'{config["General"]["Cloud"]}: maintenance started by {name}.\nNotifications are disabled.\nMessage: {message}')
    else:
        send(message=f'{config["General"]["Cloud"]}: maintenance ended.\nNotifications are enabled.')

def send(message, tag=None, check=True):
    """
    Send message to all recipients with specified tag(default to all recipients)

    Args:
        message -- string with message
        tag -- string, optional to send message only subgroup of recipients
    """
    logging.debug('send')
    global maintenance
    if maintenance:
        return
    if check:
        message = message.replace('_', '\\_').replace('*', '\\*')
    for recipient in config.sections():
        if recipient != 'General' and (tag is None or tag in config[recipient].values()):
            msg_params = ["curl", "-s", "-X", "POST", config["General"]["URL"],
                            "-d", f'chat_id={config[recipient]["telegram_id"]}',
                            "-d", f"text={message}", "-d", "parse_mode=markdown"]
            logging.debug(msg_params)
            subprocess.run(msg_params)

def sigterm_hdlr(signum, frame):
    global is_serving
    global sock
    is_serving = False
    if sock is not None:
        sock.close()

def maintenance_hdlr(signum, frame):
    global maintenance
    try:
        with open(f'{piddir}/maintenance', 'r') as f:
            name, message = f.read().split('\n', 1)
            send_maintenance_msg('start', name, message)
            maintenance = True
    except:
        maintenance = False
        send_maintenance_msg('stop')


if __name__ == '__main__':
    if sys.argv[1] == 'check': # case 'telegram_admin_alert.py check $CONFIG'
        check_config(sys.argv[2])
        exit(0)

    # case 'telegram_admin_alert.py $CONFIG $PIDDIR' -- no check

    signal.signal(signal.SIGTERM, sigterm_hdlr)
    signal.signal(signal.SIGUSR1, maintenance_hdlr)

    global config
    global piddir
    piddir = sys.argv[2]
    config = configparser.ConfigParser()
    config.read(sys.argv[1])
    logging.basicConfig(filename=config["General"]["log"], level=config["General"].getint("loglevel"))
    logging.debug("logging started")
    serve(config["General"]["IP"], config["General"].getint('port'), sys.argv[2])
