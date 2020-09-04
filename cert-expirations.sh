#!/bin/sh

echo "CA certificate:"
openssl x509 -enddate -noout -in /etc/shellpki/cacert.pem \
    | cut -d '=' -f 2 \
    | sed -e "s/^\(.*\)\ \(20..\).*/- \2 \1/"

echo ""

echo "Client certificates:"
grep "Not After" -r /etc/shellpki/certs/ \
    | sed -e "s/^.*certs\/\([-.a-z0-9]*\).*After\ :\ \(.*\).*GMT$/\2\1X/" \
    | sed -e "s/^\(.*\)\ \(20..\)\ \(.*\)$/- \2 \1 \3/" \
    | tr "X" "\n" \
    | sed '/^$/d' \
    | sort -n -k 2 -k 3M -k 4
