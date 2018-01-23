# shellpki

This script is a wrapper around openssl to manage a small PKI.

## Install

~~~
mkdir /etc/shellpki
useradd shellpki --system -M --home-dir /etc/shellpki --shell /usr/sbin/nologin
install -m 0640 openssl.cnf /etc/shellpki/
install -m 0755 shellpki.sh /usr/local/sbin/shellpki
~~~

## Usage

~~~
Usage: ./shellpki.sh <subcommand> [options] [CommonName]

Initialize PKI (create CA key and self-signed cert) :

    ./shellpki.sh init

Create a client cert with key and CSR directly generated on server
(use -p for set a password on client key) :

    ./shellpki.sh create [-p] <commonName>

Create a client cert from a CSR (doesn't need key) :

    ./shellpki.sh create -f <path>

Revoke a client cert with is commonName (CN) :

    ./shellpki.sh revoke <commonName>

List all actually valid commonName (CN) :

    ./shellpki.sh list
~~~

## License

Shellpki are in GPLv2+, see [LICENSE](LICENSE).
