#!/bin/sh

PREFIX=/etc/openvpn/ssl
CONFFILE=$PREFIX/openssl.cnf
OPENSSL=`which openssl`
TIMESTAMP=$(/bin/date +"%s")
WWWDIR=/var/www/htdocs/vpn/ssl


if [ "`id -u`" != "0" ]; then
    echo "Please become root before running shellpki!"
    echo
    echo "Press return to continue..."
    read
    exit 1
fi

init() {
    echo "Do you confirm shellpki initialization?"
    echo
    echo "Press return to continue..."
    read
    echo

    if [ ! -d $PREFIX/ca ]; then mkdir -p $PREFIX/ca; fi
    if [ ! -d $PREFIX/ca/tmp ]; then mkdir -p $PREFIX/ca/tmp; fi
    if [ ! -d $PREFIX/certs ]; then mkdir -p $PREFIX/certs; fi
    if [ ! -d $PREFIX/files ]; then mkdir -p $PREFIX/files; fi
    if [ ! -f $PREFIX/ca/index.txt ]; then touch $PREFIX/ca/index.txt; fi
    if [ ! -f $PREFIX/files/ca/serial ]; then echo 01 > $PREFIX/ca/serial; fi

$OPENSSL dhparam -out $PREFIX/ca/dh1024.pem 1024
$OPENSSL genrsa  -out $PREFIX/ca/private.key 2048

$OPENSSL req            	    \
    -config $CONFFILE		    \
    -new -x509 -days 3650      	    \
    -keyout $PREFIX/ca/private.key  \
    -out $PREFIX/ca/cacert.pem

}

create() {
    echo "Please enter your CN (Common Name)"
    read cn
    echo
    echo "Your CN is '$cn'"
    echo "Press return to continue..."
    read
    echo

    if [ -e $PREFIX/certs/$cn.crt ]; then
        echo "Please revoke actual $cn cert before creating one"
	echo
	echo "Press return to continue..."
	read
	exit 1
    fi

    DIR=$PREFIX/files/$cn-$TIMESTAMP
    mkdir $DIR

# generate private key
echo -n "Should private key be protected by a passphrase? [y/N] "
read
if [ "$REPLY" = "y" ] || [ "REPLY" = "Y" ]; then
    $OPENSSL genrsa -des3 -out $DIR/$cn.key 2048
else
    $OPENSSL genrsa -out $DIR/$cn.key 2048
fi

# generate csr req
$OPENSSL req 		\
    -new            	\
    -key $DIR/$cn.key   \
    -config $CONFFILE   \
    -out $DIR/$cn.csr

# ca sign and generate cert
$OPENSSL ca 		\
    -config $CONFFILE 	\
    -in $DIR/$cn.csr 	\
    -out $DIR/$cn.crt

# pem cert style 
cp $DIR/$cn.key $DIR/$cn.pem
cat $DIR/$cn.crt >> $DIR/$cn.pem

# copy to public certs dir
echo
echo "copy cert to public certs dir"
echo
cp -i $DIR/$cn.crt $PREFIX/certs/
cp -i $DIR/$cn.{crt,key} $WWWDIR/
chown -R root:www $WWWDIR
chmod -R u=rwX,g=rwX,o= $WWWDIR
echo

# generate client configuration

if [ -e $PREFIX/template.conf ]; then

    CA=/etc/openvpn/ssl/ca/cacert.pem
    CERT=/var/www/htdocs/vpn/ssl/$cn.crt
    KEY=/var/www/htdocs/vpn/ssl/$cn.key
    REP=/tmp

    cp $PREFIX/template.conf $REP/$cn.conf
echo "
    
<ca>
$(cat $CA)
</ca>

<cert>
$(cat $CERT)
</cert>

<key>
$(cat $KEY)
</key>
" >> $REP/$cn.conf

    echo "The configuration file is available in $REP/$cn.conf"
fi
}

revoke() {
    echo "Please enter CN (Common Name) to revoke"
    read cn
    echo
    echo "CN '$cn' will be revoked"
    echo "Press return to continue..."
    read
    echo

$OPENSSL ca \
    -config $CONFFILE \
    -revoke $PREFIX/certs/$cn.crt	

rm -i $PREFIX/certs/$cn.crt
rm -i $WWWDIR/$cn.crt
rm -i $WWWDIR/$cn.key

}

fromcsr() {
    echo "Please enter path for your CSR request file"
    read path
    echo

    if [ ! -e $path ]; then
        echo "Error in path..."
	echo
	echo "Press return to continue..."
	read
	exit 1
    fi

    echo "Please enter the CN (Common Name)"
    read cn
    echo
    echo "Your CN is '$cn'"
    echo "Press return to continue..."
    read
    echo

    DIR=$PREFIX/files/req_$cn-$TIMESTAMP
    mkdir $DIR

    cp $path $DIR

# ca sign and generate cert
$OPENSSL ca 		\
    -config $CONFFILE 	\
    -in $path 	\
    -out $DIR/$cn.crt

# copy to public certs dir
echo
echo "copy cert to public certs dir"
echo
cp -i $DIR/$cn.crt $PREFIX/certs/
echo

}


crl() {
    
$OPENSSL ca -gencrl \
    -config $CONFFILE \
    -out crl.pem

# TODO : a voir pour l'importation pdts Mozilla, Apple et Microsoft
#openssl crl2pkcs7 -in crl.pem -certfile /etc/ssl/certs/cacert.pem -out p7.pem

}

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

    crl)
    	crl
	;;

    *)
	echo "Usage: shellpki.sh {init|create|fromcsr|revoke|crl}"
	exit 1
	;;
esac

