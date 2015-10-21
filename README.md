# asuswrt-tools
Tools, scripts, config files for Asus routers (works with Asuswrt-Merlin)

## IP2BAN

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

