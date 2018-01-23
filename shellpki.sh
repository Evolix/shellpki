#!/bin/sh
#
# shellpki is a wrapper around openssl to manage a small PKI
#

set -eu

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

usage() {
    cat <<EOF
Usage: ${0} <subcommand> [options] [CommonName]

Initialize PKI (create CA key and self-signed cert) :

    ${0} init

Create a client cert with key and CSR directly generated on server
(use -p for set a password on client key) :

    ${0} create [-p] <commonName>

Create a client cert from a CSR (doesn't need key) :

    ${0} create -f <path>

Revoke a client cert with is commonName (CN) :

    ${0} revoke <commonName>

List all actually valid commonName (CN) :

    ${0} list

EOF
}

error() {
    echo "${1}" >&2
    exit 1
}

warning() {
    echo "${1}" >&2
}

ask_ca_password() {
    [ ! -f "${CADIR}/private.key" ] && error "You must initialize your's PKI with shellpki init !"
    attempt=$((${1} + 1))
    [ "${attempt}" -gt 1 ] && warning "Invalid password, retry."
    trap 'unset CA_PASSWORD' 0
    stty -echo
    printf "Password for CA key : "
    read CA_PASSWORD
    stty echo
    printf "\n"
    [ "${CA_PASSWORD}" != "" ] || ask_ca_password "${attempt}"
    CA_PASSWORD="${CA_PASSWORD}" "${OPENSSL}" rsa   \
        -in "${CADIR}/private.key"                  \
        -passin env:CA_PASSWORD                     \
        >/dev/null 2>&1                             \
        || ask_ca_password "${attempt}"
}

create() {
    from_csr=1
    with_pass=1

    while getopts ":f:p" opt; do
        case "$opt" in
            f)
            [ ! -f "${OPTARG}" ] && error "${OPTARG} must be a file"
            from_csr=0
            csr_file=$(readlink -f "${OPTARG}")
            shift 2;;
            p)
            with_pass=0
            shift;;
            :)
            error "Option -$OPTARG requires an argument."
        esac
    done

    cn="${1:-}"

    [ "${cn}" = "--" ] && shift

    if [ "${from_csr}" -eq 0 ]; then
        [ "${with_pass}" -eq 0 ] && warning "Warning: -p made nothing with -f"

        # ask for CA passphrase
        ask_ca_password 0

        # check if csr_file is a CSR
        "${OPENSSL}" req        \
            -noout -subject     \
            -in "${csr_file}"   \
            >/dev/null 2>&1     \
            || error "${csr_file} is not a valid CSR !"

        # check if csr_file contain a CN
         "${OPENSSL}" req               \
            -noout -subject             \
            -in "${csr_file}"           \
            | grep -Eo "CN\s*=[^,/]*"   \
            >/dev/null 2>&1             \
            || error "${csr_file} don't contain a CommonName !"

        # get CN from CSR
        cn=$("${OPENSSL}" req -noout -subject -in "${csr_file}"|grep -Eo "CN\s*=[^,/]*"|cut -d'=' -f2|xargs)

        # check if CN already exist
        [ -f "${CADIR}/certs/${cn}.crt" ] && error "${cn} already used !"

        # ca sign and generate cert
        CA_PASSWORD="${CA_PASSWORD}" "${OPENSSL}" ca    \
            -config "${CONFFILE}"                       \
            -in "${csr_file}"                           \
            -passin env:CA_PASSWORD                     \
            -out "${CADIR}/certs/${cn}.crt"
    else
        [ -z "${cn}" ] && usage >&2 && exit 1

        # check if CN already exist
        [ -f "${CADIR}/certs/${cn}.crt" ] && error "${cn} already used !"

        # ask for client key passphrase
        if [ "${with_pass}" -eq 0 ]; then
            trap 'unset PASSWORD' 0
            stty -echo
            printf "Password for user key : "
            read PASSWORD
            stty echo
            printf "\n"
        fi

        # ask for CA passphrase
        ask_ca_password 0

        # generate private key
        if [ "${with_pass}" -eq 0 ]; then
            PASSWORD="${PASSWORD}" "$OPENSSL" genrsa    \
                -aes256 -passout env:PASSWORD           \
                -out "${KEYDIR}/${cn}-${TIMESTAMP}.key" \
                2048 >/dev/null 2>&1
        else
            "$OPENSSL" genrsa                           \
                -out "${KEYDIR}/${cn}-${TIMESTAMP}.key" \
                2048 >/dev/null 2>&1
        fi

        if [ "${with_pass}" -eq 0 ]; then
            # generate csr req
            PASSWORD="${PASSWORD}" "$OPENSSL" req       \
                -batch -new                             \
                -key "${KEYDIR}/${cn}-${TIMESTAMP}.key" \
                -passin env:PASSWORD                    \
                -out "${CSRDIR}/${cn}-${TIMESTAMP}.csr" \
                -config /dev/stdin <<EOF
$(cat "${CONFFILE}")
commonName_default = ${cn}
EOF
        else
            # generate csr req
            "$OPENSSL" req                              \
                -batch -new                             \
                -key "${KEYDIR}/${cn}-${TIMESTAMP}.key" \
                -out "${CSRDIR}/${cn}-${TIMESTAMP}.csr" \
                -config /dev/stdin <<EOF
$(cat "${CONFFILE}")
commonName_default = ${cn}
EOF
        fi

        # ca sign and generate cert
        CA_PASSWORD="${CA_PASSWORD}" "${OPENSSL}" ca    \
            -config "${CONFFILE}"                       \
            -passin env:CA_PASSWORD                     \
            -in "${CSRDIR}/${cn}-${TIMESTAMP}.csr"      \
            -out "${CADIR}/certs/${cn}.crt"

        # check if CRT is a valid
        "${OPENSSL}" x509                           \
            -noout -subject                         \
            -in "${CADIR}/certs/${cn}.crt"          \
            >/dev/null 2>&1                         \
            || rm -f "${CADIR}/certs/${cn}.crt"

        [ -f "${CADIR}/certs/${cn}.crt" ] || error "Error in CSR creation"

        # generate pem format
        cat "${CADIR}/certs/${cn}.crt" "${CADIR}/cacert.pem" "${KEYDIR}/${cn}-${TIMESTAMP}.key" >> "${PEMDIR}/${cn}-${TIMESTAMP}.pem"

        # generate pkcs12 format
        if [ "${with_pass}" -eq 0 ]; then
            PASSWORD="${PASSWORD}"  "${OPENSSL}" pkcs12 -export -nodes -passin env:PASSWORD -passout env:PASSWORD -inkey "${KEYDIR}/${cn}-${TIMESTAMP}.key" -in "${CADIR}/certs/${cn}.crt" -out "${PKCS12DIR}/${cn}-${TIMESTAMP}.p12"
        else
             "${OPENSSL}" pkcs12 -export -nodes -passout pass: -inkey "${KEYDIR}/${cn}-${TIMESTAMP}.key" -in "${CADIR}/certs/${cn}.crt" -out "${PKCS12DIR}/${cn}-${TIMESTAMP}.p12"
        fi

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
    fi
}

revoke() {
    [ "${1}" = "" ] && usage >&2 && exit 1

    # get CN from param
    cn="${1}"

    # check if CRT exists
    [ ! -f "${CADIR}/certs/${cn}.crt" ] && error "Unknow CN : ${cn}"

    # check if CRT is a valid
    "${OPENSSL}" x509 -noout -subject -in "${CADIR}/certs/${cn}.crt" >/dev/null 2>&1 || error "${CADIR}/certs/${cn}.crt is not a valid CRT, you msust delete it !"

    # ask for CA passphrase
    ask_ca_password 0

    echo "Revoke certificate ${CADIR}/certs/${cn}.crt :"
    CA_PASSWORD="${CA_PASSWORD}" "$OPENSSL" ca  \
    -config "${CONFFILE}"                       \
    -passin env:CA_PASSWORD                     \
    -revoke "${CADIR}/certs/${cn}.crt"          \
    && rm "${CADIR}/certs/${cn}.crt"

    CA_PASSWORD="${CA_PASSWORD}" "$OPENSSL" ca \
    -config "${CONFFILE}"                      \
    -passin env:CA_PASSWORD                    \
    -gencrl -out "${CADIR}/crl.pem"
}

list() {
    [ -f /etc/shellpki/ca/index.txt ] && grep -Eo "CN\s*=[^,/]*" "${CADIR}/index.txt" | cut -d'=' -f2 | xargs -n1
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

    command=${1:-help}

    case "${command}" in
        init)
            shift
            init
        ;;

        create)
            shift
            create "$@"
        ;;

        revoke)
            shift
            revoke "$@"
        ;;

        list)
            shift
            list "$@"
        ;;

        *)
            usage >&2
            exit 1
        ;;
    esac
}

main "$@"
