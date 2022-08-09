# ShellPKI

This script is a wrapper around OpenSSL to manage a small
[PKI](https://en.wikipedia.org/wiki/Public_key_infrastructure).

## Contribution

After an update of this repo and if everything is working fine, some files must
be copied to [ansible-roles/openvpn](https://gitea.evolix.org/evolix/ansible-roles/src/branch/unstable/openvpn/files/shellpki)

## Install

### Debian

~~~
useradd shellpki --system -M --home-dir /etc/shellpki --shell /usr/sbin/nologin
mkdir /etc/shellpki
install -m 0640 openssl.cnf /etc/shellpki/
install -m 0755 shellpki /usr/local/sbin/shellpki
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
install -m 0755 shellpki /usr/local/sbin/shellpki
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

nobind
user nobody
group nogroup
persist-key
persist-tun

cipher AES-256-GCM
~~~

## Usage

~~~
Usage: shellpki <subcommand> [options] [CommonName]
~~~

Initialize PKI (create CA key and self-signed certificate) :

~~~
shellpki init [options] <commonName_for_CA>

Options
    --non-interactive           do not prompt the user, and exit if an error occurs
~~~

Create a client certificate with key and CSR directly generated on server :

~~~
shellpki create [options] <commonName>

Options
    -f, --file, --csr-file      create a client certificate from a CSR (doesn't need key)
    -p, --password              prompt the user for a password to set on the client key
        --password-file         if provided with a path to a readable file, the first line is read and set as password on the client key
        --days                  specify how many days the certificate should be valid
        --end-date              specify until which date the certificate should be valid, in YYYY/MM/DD hh:mm:ss format, UTC +0
        --non-interactive       do not prompt the user, and exit if an error occurs
        --replace-existing      if the certificate already exists, revoke it before creating a new one
~~~

Revoke a client certificate :

~~~
shellpki revoke [options] <commonName>

Options
    --non-interactive           do not prompt the user, and exit if an error occurs
~~~

List all certificates :

~~~
shellpki list <options>

Options
    -a, --all                   list all certificates : valid and revoked ones
    -v, --valid                 list all valid certificates
    -r, --revoked               list all revoked certificates
~~~

Check expiration date of valid certificates :

~~~
shellpki check
~~~

Run OCSP_D server :

~~~
shellpki ocsp <ocsp_uri:ocsp_port>
~~~

Show version :

~~~
shellpki version
~~~

Show help :

~~~
shellpki help
~~~

## Loop

We can loop over a file to revoke or create many certificates at once.

To revoke :

~~~
$ read CA_PASS
$ for cert_name in $(cat /path/to/file_certs_to_revoke); do CA_PASSWORD=$CA_PASS shellpki revoke $cert_name --non-interactive ; done
~~~

To create (without `--replace-existing`) or renew (with `--replace-existing`), with a password on the client key :

~~~
$ for cert_name in $(cat /path/to/file_certs_to_create); do apg -n 1 -m 16 -M lcN > /path/to/folder/to/store/${cert_name}.passwd; CA_PASSWORD=$CA_PASS shellpki create --replace-existing --non-interactive --password-file /path/to/folder/to/store/${cert_name}.passwd ${cert_name}; done
~~~

## License

ShellPKI is an [Evolix](https://evolix.com) project and is licensed
under the [MIT license](LICENSE).
