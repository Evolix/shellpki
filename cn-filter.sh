#!/bin/sh
#
# cn-filter.sh is a client-connect script for OpenVPN server
# It allow clients to connect only if their CN is in $AUTH_FILE
#
# You need this parameters in your's server config :
#
# script-security 3
# client-connect <path-to-cn-filter>/cn-filter.sh
#

set -eu

DATE="$(date +'%b %d %H:%M:%S')"
LOG_FILE="/var/log/openvpn/auth.log"
AUTH_FILE="/etc/openvpn/authorized_cns"

grep -qE "^${common_name}$" "${AUTH_FILE}"
if [ "$?" -eq 0 ]; then
        echo "${DATE} - Accepted login for ${common_name} from ${trusted_ip} port ${trusted_port}" >> "${LOG_FILE}"
        exit 0
else
        echo "${DATE} - Failed login for ${common_name} from ${trusted_ip} port ${trusted_port}" >> "${LOG_FILE}"
fi

exit 1
