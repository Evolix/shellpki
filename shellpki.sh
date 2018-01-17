#!/bin/sh
#
# shellpki is a wrapper around openssl to manage a small PKI
#

init() {
    umask 0177

    if [ -f "${CADIR}/private.key" ]; then
        echo "${CADIR}/private.key already exists, do you really want to erase it ?\n"
        echo "Press return to continue..."
        read -r REPLY
    fi

    [ -d "${CADIR}" ] || mkdir -pm 0700 "${CADIR}"
    [ -d "${CADIR}/certs" ] || mkdir -m 0777 "${CADIR}/certs"
    [ -d "${CADIR}/tmp" ] || mkdir -m 0700 "${CADIR}/tmp"
    [ -f "${CADIR}/index.txt" ] || touch "${CADIR}/index.txt"
    [ -f "${CADIR}/serial" ] || echo "01" > "${CADIR}/serial"

    "${OPENSSL}" req                    \
        -config "${CONFFILE}"           \
        -newkey rsa:4096 -sha512        \
        -x509 -days 3650                \
        -extensions v3_ca               \
        -keyout "${CADIR}/private.key"  \
        -out "${CADIR}/cacert.pem"
}

check_cn() {
    cn="${1}"
    if [ -f "${CADIR}/certs/${cn}.crt" ]; then
        echo "Please revoke actual ${cn} cert before creating one"
        echo
        echo "Press return to continue..."
        read -r REPLY
        exit 1
    fi
}

create() {
    umask 0137
    echo "Please enter your CN (Common Name)"
    read -r cn
    echo
    echo "Your CN is '${cn}'"
    echo "Press return to continue..."
    read -r REPLY
    echo

    # check if CN already exist
    check_cn "${cn}"

    # generate private key
    echo "Should private key be protected by a passphrase? [y/N] "
    read -r REPLY
    if [ "$REPLY" = "y" ] || [ "$REPLY" = "Y" ]; then
        "$OPENSSL" genrsa -aes256 -out "${KEYDIR}/${cn}-${TIMESTAMP}.key" 2048
    else
        "$OPENSSL" genrsa -out "${KEYDIR}/${cn}-${TIMESTAMP}.key" 2048
    fi

    # generate csr req
    "$OPENSSL" req -batch           \
        -new                        \
        -key "${KEYDIR}/${cn}-${TIMESTAMP}.key"  \
        -out "${CSRDIR}/${cn}-${TIMESTAMP}.csr"  \
        -config /dev/stdin <<EOF
$(cat "${CONFFILE}")
commonName_default = ${cn}
EOF

    # ca sign and generate cert
    "${OPENSSL}" ca                         \
        -config "${CONFFILE}"           \
        -in "${CSRDIR}/${cn}-${TIMESTAMP}.csr"       \
        -out "${CADIR}/certs/${cn}.crt"

    # generate pem format
    cat "${CADIR}/certs/${cn}.crt" "${CADIR}/cacert.pem" "${KEYDIR}/${cn}-${TIMESTAMP}.key" >> "${PEMDIR}/${cn}-${TIMESTAMP}.pem"

    # generate pkcs12 format
    openssl pkcs12 -export -nodes -passout pass: -inkey "${KEYDIR}/${cn}-${TIMESTAMP}.key" -in "${CADIR}/certs/${cn}.crt" -out "${PKCS12DIR}/${cn}-${TIMESTAMP}.p12"

    # generate openvpn format
    if [ -e "${PREFIX}/ovpn.conf" ]; then
        cat "${PREFIX}/ovpn.conf" > "${OVPNDIR}/${cn}-${TIMESTAMP}.ovpn" <<EOF
<ca>
$(cat "${CADIR}/cacert.pem")
</ca>

<cert>
$(cat "${CADIR}/certs/${cn}.crt")
</cert>

<key>
$(cat "${KEYDIR}/${cn}-${TIMESTAMP}.key")
</key>
EOF
        echo "The configuration file is available in ${OVPNDIR}/${cn}.ovpn"
    fi
}

fromcsr() {
    echo "Please enter path for your CSR request file"
    read -r path
    echo

    if [ ! -e "${path}" ]; then
    echo "Error in path..." >&2
    echo >&2
    echo "Press return to continue..." >&2
    read -r REPLY
    exit 1
    fi

    path=$(readlink -f "${path}")

    # get CN from CSR
    cn=$(openssl req -noout -subject -in "${path}"|grep -Eo "CN=[^/]*"|cut -d'=' -f2)

    # check if CN already exist
    check_cn "${cn}"

    # copy CSR to CSRDIR
    cp "$path" "${CSRDIR}/${cn}-${TIMESTAMP}.csr"

    # ca sign and generate cert
    "${OPENSSL}" ca                             \
        -config "${CONFFILE}"                   \
        -in "${CSRDIR}/${cn}-${TIMESTAMP}.csr"  \
        -out "${CADIR}/certs/${cn}.crt"
}

revoke() {
    echo "Please enter CN (Common Name) to revoke"
    read -r cn
    echo
    echo "CN '${cn}' will be revoked"
    echo "Press return to continue..."
    read -r REPLY
    echo

    [ ! -f "${CADIR}/certs/${cn}.crt" ] && echo "Unknow CN : ${cn}" >&2 && exit 1

    echo "Revoke certificate ${CADIR}/certs/${cn}.crt :"
    "$OPENSSL" ca                       \
    -config "${CONFFILE}"               \
    -revoke "${CADIR}/certs/${cn}.crt"  \
    && rm "${CADIR}/certs/${cn}.crt"

    echo "Update CRL :"
    "$OPENSSL" ca                       \
    -config "${CONFFILE}"               \
    -gencrl -out "${CADIR}/crl.pem"
}

list() {
    echo "* List of allowed CN :"
    ls -1 "${CADIR}/certs"
}

main() {
    if [ "$(id -u)" != "0" ]; then
        echo "Please become root before running ${0##*/}!" >&2
        echo >&2
        echo "Press return to continue..." >&2
        read -r REPLY
        exit 1
    fi

    # main vars
    PREFIX="/etc/shellpki"
    PKIUSER="shellpki"
    CONFFILE="${PREFIX}/openssl.cnf"
    CADIR=$(grep -E "^dir" "${CONFFILE}" | cut -d'=' -f2|xargs -n1)
    OPENSSL=$(command -v openssl)
    TIMESTAMP=$(/bin/date +"%s")
    # directories for clients key, csr, crt
    KEYDIR="${PREFIX}/private"
    CSRDIR="${PREFIX}/requests"
    PEMDIR="${PREFIX}/pem"
    PKCS12DIR="${PREFIX}/pkcs12"
    OVPNDIR="${PREFIX}/openvpn"

    if ! getent passwd "${PKIUSER}" >/dev/null || ! getent group "${PKIUSER}" >/dev/null; then
        echo "You must create ${PKIUSER} user and group !" >&2
        exit 1
    fi

    if [ ! -e "${CONFFILE}" ]; then
        echo "${CONFFILE} is missing" >&2
        >&2
        echo "Press return to continue..." >&2
        read -r REPLY
        exit 1
    fi

    # create needed dir
    [ -d "${PREFIX}" ] || mkdir -p "${PREFIX}"
    [ -d "${KEYDIR}" ] || mkdir -m 0750 "${KEYDIR}"
    [ -d "${CSRDIR}" ] || mkdir -m 0755 "${CSRDIR}"
    [ -d "${PEMDIR}" ] || mkdir -m 0750 "${PEMDIR}"
    [ -d "${PKCS12DIR}" ] || mkdir -m 0750 "${PKCS12DIR}"
    [ -d "${OVPNDIR}" ] || mkdir -m 0750 "${OVPNDIR}"

    # fix right
    find "${PREFIX}" ! -path "${CADIR}" -exec chown "${PKIUSER}":"${PKIUSER}" {} \; -exec chmod u=rwX,g=rX,o= {} \;

    case "$1" in
        init)
            init
        ;;

        create)
            create
        ;;

        fromcsr)
            fromcsr
        ;;

        revoke)
            revoke
        ;;

        list)
            list
        ;;

        *)
            echo "Usage: ${0} {init|create|fromcsr|revoke|list}" >&2
            exit 1
        ;;
    esac
}

main "$@"
