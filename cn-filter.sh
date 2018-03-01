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

set -u

AUTH_FILE="/etc/openvpn/authorized_cns"

grep -qE "^${common_name}$" "${AUTH_FILE}"
if [ "$?" -eq 0 ]; then
        logger -i -t openvpn-cn-filter -p auth.info "Accepted login for ${common_name} from ${trusted_ip} port ${trusted_port}"
        exit 0
else
        logger -i -t openvpn-cn-filter -p auth.notice "Failed login for ${common_name} from ${trusted_ip} port ${trusted_port}"
fi

exit 1
