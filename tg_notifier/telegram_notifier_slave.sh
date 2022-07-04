#!/bin/sh
##############################################################################
# Sample configuration (cib fragment in xml notation)
# ================================
# <configuration>
#   <alerts>
#     <alert id="alert_sample" path="/path/to/alert_file.sh">
#       <meta_attributes id="config_for_timestamp">
#         <nvpair id="ts_fmt" name="timestamp-format" value="%H:%M:%S.%06N"/>
#       </meta_attributes>
#       <recipient id="recipient_name" value="127.0.0.1 23"/>
#     </alert>
#   </alerts>
# </configuration>

send_message() {
    { printf "`date "+%D %T"`;$1"; sleep 1; } | telnet ${CRM_alert_recipient}
}

# No one will probably ever see this echo, unless they run the script manually.
# An alternative would be to log to the system log, or similar. (We can't send
# this to the configured recipient, because that variable won't be defined in
# this case either.)
if [ -z $CRM_alert_version ]; then
    echo "$0 must be run by Pacemaker version 1.1.15 or later"
    exit 0
fi

# Alert agents must always handle the case where no recipients are defined,
# even if it's a no-op (a recipient might be added to the configuration later).
if [ -z "${CRM_alert_recipient}" ]; then
    echo "$0 requires a recipient - 'server-ip' or 'server-ip server-port'"
    exit 0
fi

case $CRM_alert_kind in
    node)
        send_message "node;${CRM_alert_node};${CRM_alert_desc};"
        ;;
    fencing)
        # Other keys:
        #
        # CRM_alert_node
        # CRM_alert_task
        # CRM_alert_rc
        #
        send_message "fencing;${CRM_alert_desc};"
        ;;
    resource)
        # Other keys:
        #
        # CRM_alert_target_rc
        # CRM_alert_status
        # CRM_alert_rc
        #
        case ${CRM_alert_desc} in
            Cancelled) ;;
            *)
                send_message "resource;${CRM_alert_task};${CRM_alert_interval};${CRM_alert_rsc};${CRM_alert_node};${CRM_alert_rc};${CRM_alert_target_rc};"
                ;;
        esac
        ;;
    attribute)
        # Pass
        ;;

    *)
        send_message "unhandled;$CRM_alert_kind alert;"
        ;;
esac
