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

Initialize PKI creating CA key and certificate :

~~~
shellpki init
~~~

Create a certificate and key on the server :

~~~
shellpki create
~~~

Create a certificate without key from a CSR :

~~~
shellpki fromcsr
~~~

Revoke a certificate :

~~~
shellpki revoke
~~~

## License

Shellpki are in GPLv2+, see [LICENSE](LICENSE).
