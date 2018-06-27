#!/bin/sh
#
# shellpki is a wrapper around openssl to manage a small PKI
#

set -eu

init() {
    umask 0177

    [ -d "${CADIR}" ] || mkdir -m 0750 "${CADIR}"
    [ -d "${CRTDIR}" ] || mkdir -m 0750 "${CRTDIR}"
    [ -f "${INDEX}" ] || touch "${INDEX}"
    [ -f "${CRL}" ] || touch "${CRL}"
    [ -f "${SERIAL}" ] || echo "01" > "${SERIAL}"

    cn="${1:-}"
    [ -z "${cn}" ] && usage >&2 && exit 1

    if [ -f "${CAKEY}" ]; then
        printf "%s already exists, do you really want to erase it ? [y/N] " ${CAKEY}
        read -r REPLY
        resp=$(echo "${REPLY}"|tr 'Y' 'y')
        [ "${resp}" = "y" ] && rm -f "${CAKEY}" "${CACERT}"
    fi

    [ ! -f "${CAKEY}" ] && "$OPENSSL"   \
        genrsa                          \
        -out "${CAKEY}"                 \
        -aes256 4096 >/dev/null 2>&1

    if [ -f "${CACERT}" ]; then
        printf "%s already exists, do you really want to erase it ? [y/N] " ${CACERT}
        read -r REPLY
        resp=$(echo "${REPLY}"|tr 'Y' 'y')
        [ "${resp}" = "y" ] && rm "${CACERT}"
    fi

    [ ! -f "${CACERT}" ] && ask_ca_password 0

    [ ! -f "${CACERT}" ] && CA_PASSWORD="${CA_PASSWORD}" "${OPENSSL}"   \
         req                                                            \
        -batch -sha512                                                  \
        -x509 -days 3650                                                \
        -extensions v3_ca                                               \
        -key "${CAKEY}"                                                 \
        -out "${CACERT}"                                                \
        -passin env:CA_PASSWORD                                         \
        -config /dev/stdin <<EOF
$(cat "${CONFFILE}")
commonName_default = ${cn}
EOF
}

usage() {
    cat <<EOF
Usage: ${0} <subcommand> [options] [CommonName]

Initialize PKI (create CA key and self-signed cert) :

    ${0} init <commonName_for_CA>

Create a client cert with key and CSR directly generated on server
(use -p for set a password on client key) :

    ${0} create [-p] <commonName>

Create a client cert from a CSR (doesn't need key) :

    ${0} create -f <path>

Revoke a client cert with is commonName (CN) :

    ${0} revoke <commonName>

List all actually valid commonName (CN) :

    ${0} list [-a|v|r]

Check expiration date of valid certificates :

    ${0} check

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
    [ ! -f "${CAKEY}" ] && error "You must initialize your's PKI with shellpki init !"
    attempt=$((${1} + 1))
    [ "${attempt}" -gt 1 ] && warning "Invalid password, retry."
    trap 'unset CA_PASSWORD' 0
    stty -echo
    printf "Password for CA key : "
    read -r CA_PASSWORD
    stty echo
    printf "\n"
    [ "${CA_PASSWORD}" != "" ] || ask_ca_password "${attempt}"
    CA_PASSWORD="${CA_PASSWORD}" "${OPENSSL}" rsa   \
        -in "${CAKEY}"                              \
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
        [ -f "${CRTDIR}/${cn}.crt" ] && error "${cn} already used !"

        # ca sign and generate cert
        CA_PASSWORD="${CA_PASSWORD}" "${OPENSSL}" ca    \
            -config "${CONFFILE}"                       \
            -in "${csr_file}"                           \
            -passin env:CA_PASSWORD                     \
            -out "${CRTDIR}/${cn}.crt"

        echo "The CRT file is available in ${CRTDIR}/${cn}.crt"
    else
        [ -z "${cn}" ] && usage >&2 && exit 1

        # check if CN already exist
        [ -f "${CRTDIR}/${cn}.crt" ] && error "${cn} already used !"

        # ask for client key passphrase
        if [ "${with_pass}" -eq 0 ]; then
            trap 'unset PASSWORD' 0
            stty -echo
            printf "Password for user key : "
            read -r PASSWORD
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
            -out "${CRTDIR}/${cn}.crt"

        # check if CRT is a valid
        "${OPENSSL}" x509                           \
            -noout -subject                         \
            -in "${CRTDIR}/${cn}.crt"          \
            >/dev/null 2>&1                         \
            || rm -f "${CRTDIR}/${cn}.crt"

        [ -f "${CRTDIR}/${cn}.crt" ] || error "Error in CSR creation"

        chmod 640 "${CRTDIR}/${cn}.crt"

        echo "The CRT file is available in ${CRTDIR}/${cn}.crt"

        # generate pkcs12 format
        if [ "${with_pass}" -eq 0 ]; then
            PASSWORD="${PASSWORD}"  "${OPENSSL}" pkcs12 -export -nodes -passin env:PASSWORD -passout env:PASSWORD -inkey "${KEYDIR}/${cn}-${TIMESTAMP}.key" -in "${CRTDIR}/${cn}.crt" -out "${PKCS12DIR}/${cn}-${TIMESTAMP}.p12"
        else
             "${OPENSSL}" pkcs12 -export -nodes -passout pass: -inkey "${KEYDIR}/${cn}-${TIMESTAMP}.key" -in "${CRTDIR}/${cn}.crt" -out "${PKCS12DIR}/${cn}-${TIMESTAMP}.p12"
        fi

        chmod 640 "${PKCS12DIR}/${cn}-${TIMESTAMP}.p12"
        echo "The PKCS12 config file is available in ${PKCS12DIR}/${cn}-${TIMESTAMP}.p12"

        # generate openvpn format
        if [ -e "${CADIR}/ovpn.conf" ]; then
            cat "${CADIR}/ovpn.conf" - > "${OVPNDIR}/${cn}-${TIMESTAMP}.ovpn" <<EOF
<ca>
$(cat "${CACERT}")
</ca>

<cert>
$(cat "${CRTDIR}/${cn}.crt")
</cert>

<key>
$(cat "${KEYDIR}/${cn}-${TIMESTAMP}.key")
</key>
EOF
            chmod 640 "${OVPNDIR}/${cn}-${TIMESTAMP}.ovpn"
            echo "The OpenVPN config file is available in ${OVPNDIR}/${cn}-${TIMESTAMP}.ovpn"
        fi
    fi
}

revoke() {
    [ "${1}" = "" ] && usage >&2 && exit 1

    # get CN from param
    cn="${1}"

    # check if CRT exists
    [ ! -f "${CRTDIR}/${cn}.crt" ] && error "Unknow CN : ${cn}"

    # check if CRT is a valid
    "${OPENSSL}" x509 -noout -subject -in "${CRTDIR}/${cn}.crt" >/dev/null 2>&1 || error "${CRTDIR}/${cn}.crt is not a valid CRT, you msust delete it !"

    # ask for CA passphrase
    ask_ca_password 0

    echo "Revoke certificate ${CRTDIR}/${cn}.crt :"
    CA_PASSWORD="${CA_PASSWORD}" "$OPENSSL" ca  \
    -config "${CONFFILE}"                       \
    -passin env:CA_PASSWORD                     \
    -revoke "${CRTDIR}/${cn}.crt"          \
    && rm "${CRTDIR}/${cn}.crt"

    CA_PASSWORD="${CA_PASSWORD}" "$OPENSSL" ca \
    -config "${CONFFILE}"                      \
    -passin env:CA_PASSWORD                    \
    -gencrl -out "${CRL}"
}

list() {
    [ -f "${INDEX}" ] || exit 0

    list_valid=0
    list_revoked=1

    while getopts "avr" opt; do
        case "$opt" in
            a)
            list_valid=0
            list_revoked=0
            shift;;
            v)
            list_valid=0
            list_revoked=1
            shift;;
            r)
            list_valid=1
            list_revoked=0
            shift;;
        esac
    done

    [ "${list_valid}" -eq 0 ] && certs=$(grep "^V" "${INDEX}")

    [ "${list_revoked}" -eq 0 ] && certs=$(grep "^R" "${INDEX}")

    [ "${list_valid}" -eq 0 ] && [ "${list_revoked}" -eq 0 ] && certs=$(cat "${INDEX}")

    echo "${certs}" | grep -Eo "CN\s*=[^,/]*" | cut -d'=' -f2 | xargs -n1
}

check() {
    # default expiration alert
    # TODO : permit override with parameters
    min_day=90
    cur_epoch=$(date -u +'%s')

    for cert in ${CRTDIR}/*; do
        end_date=$(openssl x509 -noout -enddate -in "${cert}" | cut -d'=' -f2)
        end_epoch=$(date -ud "${end_date}" +'%s')
        diff_epoch=$((end_epoch - cur_epoch))
        diff_day=$((diff_epoch/60/60/24))
        if [ "${diff_day}" -lt "${min_day}" ]; then
            if [ "${diff_day}" -le 0 ]; then
                echo "${cert} has expired"
            else
                echo "${cert} expire in ${diff_day} days"
            fi
        fi
    done
}

main() {
    [ "$(id -u)" -eq 0 ] || error "Please become root before running ${0} !"

    # default config
    # TODO : override with /etc/default/shellpki
    CONFFILE="/etc/shellpki/openssl.cnf"
    PKIUSER="shellpki"

    # retrieve CA path from config file
    CADIR=$(grep -E "^dir" "${CONFFILE}" | cut -d'=' -f2|xargs -n1)
    CAKEY=$(grep -E "^private_key" "${CONFFILE}" | cut -d'=' -f2|xargs -n1|sed "s~\$dir~${CADIR}~")
    CACERT=$(grep -E "^certificate" "${CONFFILE}" | cut -d'=' -f2|xargs -n1|sed "s~\$dir~${CADIR}~")
    CRTDIR=$(grep -E "^certs" "${CONFFILE}" | cut -d'=' -f2|xargs -n1|sed "s~\$dir~${CADIR}~")
    TMPDIR=$(grep -E "^new_certs_dir" "${CONFFILE}" | cut -d'=' -f2|xargs -n1|sed "s~\$dir~${CADIR}~")
    INDEX=$(grep -E "^database" "${CONFFILE}" | cut -d'=' -f2|xargs -n1|sed "s~\$dir~${CADIR}~")
    SERIAL=$(grep -E "^serial" "${CONFFILE}" | cut -d'=' -f2|xargs -n1|sed "s~\$dir~${CADIR}~")
    CRL=$(grep -E "^crl" "${CONFFILE}" | cut -d'=' -f2|xargs -n1|sed "s~\$dir~${CADIR}~")

    # directories for clients key, csr, crt
    KEYDIR="${CADIR}/private"
    CSRDIR="${CADIR}/requests"
    PKCS12DIR="${CADIR}/pkcs12"
    OVPNDIR="${CADIR}/openvpn"

    OPENSSL=$(command -v openssl)
    TIMESTAMP=$(/bin/date +"%s")

    if ! getent passwd "${PKIUSER}" >/dev/null || ! getent group "${PKIUSER}" >/dev/null; then
        error "You must create ${PKIUSER} user and group !"
    fi

    [ -e "${CONFFILE}" ] || error "${CONFFILE} is missing"

    mkdir -p "${CADIR}" "${CRTDIR}" "${KEYDIR}" "${CSRDIR}" "${PKCS12DIR}" "${OVPNDIR}" "${TMPDIR}"

    command=${1:-help}

    case "${command}" in
        init)
            shift
            init "$@"
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

        check)
            shift
            check "$@"
        ;;

        *)
            usage >&2
            exit 1
        ;;
    esac

    # fix right
    chown -R "${PKIUSER}":"${PKIUSER}" "${CADIR}"
    chmod 750 "${CADIR}" "${CRTDIR}" "${KEYDIR}" "${CSRDIR}" "${PKCS12DIR}" "${OVPNDIR}" "${TMPDIR}"
    chmod 600 "${INDEX}"* "${SERIAL}"* "${CAKEY}" "${CRL}"
    chmod 640 "${CACERT}"
}

main "$@"
