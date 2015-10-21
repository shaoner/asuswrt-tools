# asuswrt-tools
Tools, scripts, config files for Asus routers (works with Asuswrt-Merlin)

## IP2BAN

It allows to ban external IP addresses that try to reach an invalid port in your router.

### Configuration

#### IP2BAN_WHITELIST_TCP_PORTS (default: "")

Allowed ports separated by space. If the connection has already been established using this port, the source IP won't be ban.
Example: `IP2BAN_WHITELIST_TCP_PORTS="80 22 25"`

#### IP2BAN_WHITELIST_IPS (default: "")

Allowed ip addresses separated by space. If the connection has already been established with this ip, the source IP won't be ban
Example: `IP2BAN_WHITELIST_IPS="8.8.8.8 2.2.2.2"`

#### IP2BAN_ATTEMPT_COUNT (default: 1)

Number of attempts allowed. By default the 1st attempt to an invalid port is banned 20 minutes

#### IP2BAN_BAN_TIME (default: 1200)

Number of seconds the source IP is banned

#### IP2BAN_ACTION (default: DROP)

This is the action to take when a ban ip tries to connect. By default, the packet is dropped, but it can be rejected as well or even accepted
Example: `IP2BAN_ACTION="REJECT --reject-with icmp-port-unreachable"`

#### IP2BAN_LOG_BLACKLISTED (default: 0)

If set to 1, it logs when an ip is blacklisted

#### IP2BAN_LOG_PREFIX (default: "IP2BAN:")

The prefix to set to blacklisted logs

#### IP2BAN_JAIL_NAME (default: IP2BAN_JAIL)

The name of the jail

#### IP2BAN_ZONE_CHAIN (default: IP2BAN_ZONE)

The name of the chain in which an action is taken

- if whitelisted port -> go back to input processing
- if whitelisted ip -> go back to input processing
- if already blacklisted ip or reach the number of attempts -> action (drop, reject, etc)
- else -> go back to input processing

#### IP2BAN_ZONE_CHAIN_SET (default: IP2BAN_ZONE_SET)

The name of the chain in which an IP is declared banned. If a packet reaches this zone, it is considered "banned"

#### IP2BAN_DRY_RUN (default: 0)

If set to 1, print the iptables rules without adding them (can be overrided by -n option)

### Install

You can set it as the default firewall-start script:
```
# mv ip2ban.sh /jffs/scripts/firewall-start
# chmod +x /jffs/scripts/firewall-start
```

Or you can source it from your firewall-start script

```
# mv ip2ban.sh /jffs/scripts
```

```shell
#!/bin/sh

# Your stuff here

source /jffs/scripts/ip2ban.sh $1
```

### Usage

The script can be configured and comes with some options:

```
ip2ban [-n] [-l] [-a ACTION] INTERFACE
ip2ban [-n] -r
ip2ban -h

-h       Display this help
-n       Only print iptables statements
-r       Restore iptables as it was
-l       Enable logs when an ip is banned
-a ACTION        Set an action to take when a banned ip is detected (ACCEPT, DROP, REJECT, etc)
```

By default if no wan interface is given, it tries to find one by itself but that's not really reliable

