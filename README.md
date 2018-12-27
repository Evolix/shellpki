# ShellPKI

This script is a wrapper around OpenSSL to manage a small
[PKI](https://en.wikipedia.org/wiki/Public_key_infrastructure).

## Install

### Debian

~~~
useradd shellpki --system -M --home-dir /etc/shellpki --shell /usr/sbin/nologin
mkdir /etc/shellpki
install -m 0640 openssl.cnf /etc/shellpki/
install -m 0755 shellpki.sh /usr/local/sbin/shellpki
chown -R shellpki: /etc/shellpki
~~~

~~~
# visudo -f /etc/sudoers.d/shellpki
%shellpki ALL = (root) /usr/local/sbin/shellpki
~~~

### OpenBSD

~~~
useradd -r 1..1000 -d /etc/shellpki -s /sbin/nologin _shellpki
mkdir /etc/shellpki
install -m 0640 openssl.cnf /etc/shellpki/
install -m 0755 shellpki.sh /usr/local/sbin/shellpki
chown -R _shellpki:_shellpki /etc/shellpki
~~~

~~~
# visudo -f /etc/sudoers
%_shellpki ALL = (root) /usr/local/sbin/shellpki
~~~

## OpenVPN

If you want auto-generation of the OpenVPN config file in
/etc/shellpki/openvpn, you need to create a template file in
/etc/shellpki/ovpn.conf, eg. :

~~~
client
dev tun
tls-client
proto udp

remote ovpn.example.com 1194

persist-key
persist-tun

cipher AES-256-CBC
~~~

## Usage

~~~
Usage: ./shellpki.sh <subcommand> [options] [CommonName]
~~~

Initialize PKI (create CA key and self-signed cert) :

~~~
   ./shellpki.sh init <commonName_for_CA>
~~~

Create a client cert with key and CSR directly generated on server
(use -p for set a password on client key) :

~~~
    ./shellpki.sh create [-p] <commonName>
~~~

Create a client cert from a CSR (doesn't need key) :

~~~
    ./shellpki.sh create -f <path>
~~~

Revoke a client cert with is commonName (CN) :

~~~
    ./shellpki.sh revoke <commonName>
~~~

List all actually valid commonName (CN) :

~~~
    ./shellpki.sh list
~~~

## License

ShellPKI is an [Evolix](https://evolix.com) project and is licensed
under the [MIT license](LICENSE).
