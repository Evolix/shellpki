# shellpki

This script is a wrapper around openssl to manage all the pki stuff
for openvpn.

# Usage

First create the directory, put the script in it and the openssl
configuration file. You may certainly need to edit the configuration.

    mkdir -p /etc/openvpn/ssl
    cp /path/to/shellpki.sh /etc/openvpn/ssl/
	cp /path/to/openssl.cnf /etc/openvpn/ssl/
	$EDITOR /etc/openvpn/ssl/openssl.cnf

Then you'll need to initialize the pki.

    cd /etc/openvpn/ssl
    sh shellpki.sh init

Once it's done, you can create all the certificates you need.

    sh shellpki.sh create

