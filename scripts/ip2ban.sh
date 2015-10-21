#! /bin/sh

# IP2BAN_WHITELIST_TCP_PORTS
# --------------------
# Allowed ports separated by space
# If the connection has already been established using this port,
# the source IP won't be ban
# Example: IP2BAN_WHITELIST_TCP_PORTS="80 22 25"
IP2BAN_WHITELIST_TCP_PORTS=""

# IP2BAN_WHITELIST_IPS
# --------------------
# Allowed ip addresses separated by space
# If the connection has already been established with this ip,
# the source IP won't be ban
# Example: IP2BAN_WHITELIST_IPS="8.8.8.8 2.2.2.2"
IP2BAN_WHITELIST_IPS=""

# IP2BAN_ATTEMPT_COUNT
# --------------------
# Number of attempts allowed
# By default the 1st attempt to an is banned 20 minutes
IP2BAN_ATTEMPT_COUNT=1

# IP2BAN_BAN_TIME
# --------------------
# Number of seconds the source IP is banned
IP2BAN_BAN_TIME=1200

# IP2BAN_ACTION
# --------------------
# This is the action to take when a ban ip tries to connect
# By default, the packet is dropped, but it can be rejected as well
# Example:
# IP2BAN_ACTION="REJECT --reject-with icmp-port-unreachable"
IP2BAN_ACTION="DROP"

# IP2BAN_LOG_BLACKLISTED
# --------------------
# If set to 1, it logs when an ip is blacklisted
IP2BAN_LOG_BLACKLISTED=0

# IP2BAN_LOG_PREFIX
# --------------------
# The prefix to set to blacklisted logs
IP2BAN_LOG_PREFIX="BLACKLISTED: "

# IP2BAN_JAIL_NAME
# --------------------
# Name of the jail
IP2BAN_JAIL_NAME="BLACKLIST_JAIL"

# IP2BAN_ZONE_CHAIN
# --------------------
# Name of the chain in which an action is taken
# - if whitelisted port -> go back to input processing
# - if whitelisted ip -> go back to input processing
# - if already blacklisted ip or reach the number of attempts -> action (drop, reject, etc)
# - else -> go back to input processing
IP2BAN_ZONE_CHAIN="ZONE_LIST"

# IP2BAN_ZONE_CHAIN_SET
# --------------------
# Name of the chain in which an IP is declared banned.
# If a packet reaches this zone, it is marked
IP2BAN_ZONE_CHAIN_SET="${IP2BAN_ZONE_CHAIN}_SET"

# IP2BAN_DRY_RUN
# --------------------
# If set to 1, print the iptables rules without adding them
# Set IP2BAN_DRY_RUN to 0, to add all the rules
# Can be overrided by -n option
IP2BAN_DRY_RUN=0

ip2ban_usage()
{
    echo "ip2ban [-n] [-l] [-a ACTION] INTERFACE"
    echo "ip2ban [-n] -r"
    echo "ip2ban -h"
    echo
    echo -e "-h \n\t Display this help"
    echo -e "-n \n\t Only print iptables statements"
    echo -e "-r \n\t Restore iptables as it was"
    echo -e "-l \n\t Enable logs when an ip is banned"
    echo -e "-a ACTION \n\t Set an action to take when a banned ip is detected (ACCEPT, DROP, REJECT, etc)"
    echo
    echo "This script can be executed as ./$0 or sourced: source $0 eth0"
}

ip2ban_chain_exist()
{
    iptables -L "$1" >/dev/null 2>&1
    return $?
}

ip2ban_rule_number()
{
    iptables -L INPUT --line-numbers | grep "$*" | head -1 | egrep -o '^[0-9]+'
}

ip2ban_rm_input_chain()
{
    if [ -z "$1" ]; then
        echo "Error: no input chain given"
        return 1
    fi
    # Remove the chain and its links
    if [ "$#" -gt 1 ] && [ "$2" = "force" ]; then
        iptables -D INPUT -j "$1"
        iptables -F "$1"
        iptables -X "$1"
    elif ip2ban_chain_exist "$1"; then
        local rnum=$(ip2ban_rule_number "$1")
        if [ ! -z "$rnum" ]; then
            ip2ban_iptables -D INPUT "$rnum" || return 1
        fi
        ip2ban_iptables -F "$1" || return 1
        ip2ban_iptables -X "$1" || return 1
    fi
 }

ip2ban_restore_rules()
{
    ip2ban_rm_input_chain "INPUT_$IP2BAN_ZONE_CHAIN" $1 || return 1
    ip2ban_rm_input_chain "INPUT_$IP2BAN_ZONE_CHAIN_SET" $1 || return 1
}

ip2ban_create_input_chain()
{
    ip2ban_rm_input_chain "$1" || return 1
    # create it
    ip2ban_iptables -N "$1" || return 1
}

ip2ban_iptables()
{
    if [ "$IP2BAN_DRY_RUN" -eq 0 ]; then
        iptables $@ || (echo "Error: fail to apply \`iptables $@'" >&2; ip2ban_restore_rules force; return 1)
    else
        echo "iptables $@"
    fi
}

ip2ban_is_valid_interface()
{
    ifconfig "$1" | grep -q inet >/dev/null 2>&1
    return $?
}

ip2ban_find_wan_interface()
{
    local list=$(ifconfig | grep -o '^eth[0-9]')
    IFS='
'
    for ifc in $list; do
        if ip2ban_is_valid_interface "$ifc"; then
            echo "$ifc"
            return
        fi
    done
}

ip2ban_ip_from_interface()
{
    if ip2ban_is_valid_interface "$1"; then
        ifconfig "$1" | egrep -o "inet addr:[0-9.]+" | cut -d: -f2
    fi
}

ip2ban_create_rules()
{
    local ifc=$1
    if [ -z "$ifc" ] || ! ip2ban_is_valid_interface "$ifc"; then
        echo "Error: invalid interface $ifc" >&2
        return 1
    fi
    local newstate=$(ip2ban_rule_number 'state NEW')
    if [ -z "$newstate" ]; then
        echo "Error: cannot find the state NEW line, is iptables running and configured?"
        return 1
    fi
    local in_zone_chain="INPUT_$IP2BAN_ZONE_CHAIN"
    local in_zone_chain_set="INPUT_$IP2BAN_ZONE_CHAIN_SET"
    local allowed_ips=$(echo $IP2BAN_WHITELIST_IPS | sed 's/ /,/')
    local allowed_ports=$(echo $IP2BAN_WHITELIST_TCP_PORTS | sed 's/ /,/')
    ip2ban_create_input_chain $in_zone_chain || return 1
    ip2ban_create_input_chain $in_zone_chain_set || return 1

    # Banned ip addresses are handled here
    ip2ban_iptables -A $in_zone_chain -m recent --update --seconds $IP2BAN_BAN_TIME --hitcount $IP2BAN_ATTEMPT_COUNT --name "$IP2BAN_JAIL_NAME" --rsource -j $IP2BAN_ACTION || return 1

    # Allowed ip addresses
    if [ ! -z "$allowed_ips" ]; then
        ip2ban_iptables -A $in_zone_chain_set -s "$allowed_ips" -j RETURN || return 1
    fi
    # Allowed ports
    if [ ! -z "$allowed_ips" ]; then
        ip2ban_iptables -A $in_zone_chain_set -m multiport -p tcp --sports "$allowed_ports" -j RETURN || return 1
    fi
    # Allow wan IP itself
    ip2ban_iptables -A $in_zone_chain_set -s "$(ip2ban_ip_from_interface $ifc)" -j RETURN || return 1

    if [ "$IP2BAN_LOG_BLACKLISTED" -eq 1 ]; then
        ip2ban_iptables -A $in_zone_chain_set -j LOG --log-prefix "$IP2BAN_LOG_PREFIX" || return 1
    fi
    # Set an ip address as banned
    ip2ban_iptables -A $in_zone_chain_set -m recent --set --name "$IP2BAN_JAIL_NAME" --rsource || return 1
    ip2ban_iptables -A $in_zone_chain_set -j $IP2BAN_ACTION
    # Insert in INPUT chain
    local lastdrop=$(iptables -L INPUT --line-numbers | tail -1 | grep 'DROP' | egrep -o '^[^ ]+')
    ip2ban_iptables -I INPUT $newstate -j "$in_zone_chain" || return 1
    if [ -z "$lastdrop" ]; then
        ip2ban_iptables -A INPUT -i "$ifc" -j $in_zone_chain_set || return 1
    else
        ip2ban_iptables -I INPUT $lastdrop -i "$ifc" -j $in_zone_chain_set || return 1
    fi
}

# If the script is not sourced
if [ -z "$_" ]; then
    # Parse options
    RESTORE=0
    while [ ! -z "$1" ] && [ "${1:0:1}" = "-" ]; do
        case $1 in
            -h)
                ip2ban_usage
                exit 0
                ;;
            -n)
                IP2BAN_DRY_RUN=1
                ;;
            -r)
                RESTORE=1
                ;;
            -l)
                IP2BAN_LOG_BLACKLISTED=1
                ;;
            -a)
                if [ $# -lt 2 ]; then
                    echo "Error: empty or invalid action" >&2
                    exit 1
                fi
                IP2BAN_ACTION="$2"
                shift
                ;;
        esac
        shift
    done
    if [ "$RESTORE" -eq 1 ]; then
        ip2ban_restore_rules
        exit $?
    fi
    if [ -z "$1" ]; then
        IFC=$(ip2ban_find_wan_interface)
        if [ ! -z "$IFC" ]; then
            ip2ban_create_rules "$IFC"
            exit $?
        else
            echo "Error: cannot find a valid interface" >&2
            exit 1
        fi
    else
        ip2ban_create_rules "$1"
        exit $?
    fi
fi
