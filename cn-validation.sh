#!/bin/sh
# 
# cn-validation.sh is a client-connect script for OpenVPN server
# When connecting using the PAM plugin, it allow clients to connect only if their CN is equal to their UNIX username
#
# You need this parameters in your's server config :
#
# script-security 2
# client-connect <path-to-cn-filter>/cn-validation.sh
#

set -u

if [ "${common_name}" = "${username}" ]; then
        logger -i -t openvpn-cn-validation -p auth.info "Accepted login for ${common_name} from ${trusted_ip} port ${trusted_port}"
        exit 0
else
        logger -i -t openvpn-cn-validation -p auth.notice "Failed login for CN ${common_name} / username ${username} from ${trusted_ip} port ${trusted_port}"
fi

exit 1
