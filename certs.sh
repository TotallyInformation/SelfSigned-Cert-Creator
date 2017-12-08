#!/usr/bin/env bash

# Create self-signed certificates and keys for a CA and a server
# Primarily for using with SSL/TLS to secure communications
# between local servers and clients NOT ON THE INTERNET!
#
# Inspired by: https://github.com/Daplie/nodejs-self-signed-certificate-example/blob/master/make-root-ca-and-certificates.sh
#
# Use as: bash make-certs.sh 'localhost.daplie.com'
#
# Author: Julian Knight, Totally Information, 2016-11-05
# Updates:
#   v1.1 2017-12-08: JK change to add SAN as now required by Chrome
# License: MIT, may be freely reused.

echo "**********************************************************************************"
echo "* Create a Certificate Authority certificate and keys along with a server and    *"
echo "* a client certificate based on the CA.                                          *"
echo "*                                                                                *"
echo "* Use the resulting server certificate for running servers (e.g. Apache, NGINX,  *"
echo "* Node.JS, ExpressJS, etc.) with SSL/TLS encrypted connections.                  *"
echo "*                                                                                *"
echo "* Use the CA's PUBLIC certificate on every client that may access the server by  *"
echo "* importing the CA public certificate into the client's trusted root certificate *"
echo "* store. This stops clients (e.g. browsers) from complaining that the server's   *"
echo "* certificate is 'untrusted'.                                                    *"
echo "*                                                                                *"
echo "* This saves you from having to purchase an expensive certificate from a         *"
echo "* publically trusted certificate authority. It also saves the problems           *"
echo "* with trying to get Let's Encrypt free certificates working on private          *"
echo "* networks.                                                                      *"
echo "*                                                                                *"
echo "* This script creates the following folders under the current location:          *"
echo "*    ./server   :: Server certificates                                           *"
echo "*    ./client   :: Client certificates and CA public certificate                 *"
echo "*    ./ca       :: CA Certificates - keep these safe, OFFLINE!                   *"
echo "*                  The CA certificates can (and should) be reused to create new  *"
echo "*                  server and client certificates.                               *"
echo "**********************************************************************************"
echo "* VERSION: 1.1 2017-11-08                                                        *"
echo "**********************************************************************************"

if [[ ! ${1+x} ]]; then
	echo "No FQDN parameter given - exiting"
	exit 1
else
	echo "FQDN is '$1'"
fi

FQDN=$1

# PLEASE UPDATE THE FOLLOWING VARIABLES FOR YOUR NEEDS.
HOSTNAME="totallyinformation"
DOT="net"
COUNTRY="UK"
STATE="South Yorks"
CITY="Sheffield"
ORGANIZATION="Totally Information"
ORGANIZATION_UNIT="IT"
EMAIL="webmaster@$HOSTNAME.$DOT"
# ----------------------------------------------------

echo "Make directories to work from"
mkdir -p ./{server,client,ca,tmp}

# -------- CA -------- #
# You can reuse these  #
# -------------------- #

echo "Create your very own Root Certificate Authority"
openssl genrsa \
  -out ca/my-private-root-ca.privkey.pem \
  2048

echo "Self-sign your Root Certificate Authority"
# Since this is private, the details can be as bogus as you like
openssl req \
  -x509 \
  -new \
  -nodes \
  -days 9999 \
  -key  ca/my-private-root-ca.privkey.pem \
  -out  ca/my-private-root-ca.cert.pem \
  -subj "/C=$COUNTRY/ST=$STATE/L=$CITY/O=$ORGANIZATION/CN=$HOSTNAME.$DOT"

echo "Import ca/my-private-root-ca.cert.pem to Windows Trusted Root store if required"

echo "Create temp OpenSSL configuration file"

# Required as this is the only way to add SubjectAltName fields which are now required
# by Chrome.
cat >tmp/ssl.cnf <<EOL
default_bits = 2048
prompt = no
default_md = sha256
x509_extensions = v3_req
authorityKeyIdentifier=keyid,issuer
basicConstraints=CA:FALSE

# Adjust to need @see https://www.openssl.org/docs/man1.1.0/apps/x509v3_config.html
keyUsage = digitalSignature, nonRepudiation, keyEncipherment, dataEncipherment
# Adjust to need @see https://www.openssl.org/docs/man1.1.0/apps/x509v3_config.html
extendedKeyUsage = serverAuth, clientAuth, codeSigning, emailProtection, timeStamping, msCodeInd, msCTLSign, msEFS

distinguished_name = dn
subjectAltName = @alt_names

[dn]
C = $COUNTRY
ST = $STATE
L = $CITY
O = $ORGANIZATION
OU = $ORGANIZATION_UNIT
emailAddress = $EMAIL
CN = $HOSTNAME.$DOT

[alt_names]
# Comment out the localhost/127 addresses if not required
DNS.1 = $FQDN
IP.1 = $FQDN
DNS.2 = localhost
IP.2 = 127.0.0.1
#email.1 = copy
#email.2 = me@$HOSTNAME.$DOT
EOL

# ------------- Server ------------- #
# Need one of these for each server  #
# ---------------------------------- #

echo " "
echo "Create a Server Private Key - KEEP THIS SECURE ON THE SERVER!"
openssl genrsa \
  -out server/privkey.pem \
  2048

echo " "
echo "Create a request from your Server, which your Root CA will sign"
# 1 for each domain such as 192.168.1.167, example.com, *.example.com, awesome.example.com
# NOTE: You MUST match CN to the domain name or ip address you want to use
# Multi-domain certs require the use of a configuration file and SubjectAltName
openssl req -new \
  -key  server/privkey.pem \
  -out  tmp/csr.pem \
  -config tmp/ssl.cnf
  #-subj "/C=$COUNTRY/ST=$STATE/L=$CITY/O=$ORGANIZATION/CN=${FQDN}"

echo " "
echo "Sign the request from Device with your Root CA, creates the actual cert"
openssl x509 \
  -CAcreateserial -req \
  -in    tmp/csr.pem \
  -CA    ca/my-private-root-ca.cert.pem \
  -CAkey ca/my-private-root-ca.privkey.pem \
  -out   server/cert.pem \
  -days  9999

echo " "
echo "Create a combined pfx file for convenience"
openssl pkcs12 -export \
	-certfile ca/my-private-root-ca.cert.pem \
	-inkey server/privkey.pem \
	-in server/cert.pem \
	-out server/cert.pfx \
	-name "Self-Signed Server Certificate"

echo " "
echo "Copy root ca cert to server & client as chain.pem"
rsync -a ca/my-private-root-ca.cert.pem server/chain.pem
rsync -a ca/my-private-root-ca.cert.pem client/chain.pem
echo "Create a server full chain cert for SSL/TLS use"
cat server/cert.pem server/chain.pem > server/fullchain.pem

echo " "
echo "Use in Node.JS as: sslOpts = { key: 'server/privkey.pem', cert: 'server/fullchain.pem' }"
echo "  as this is self-signed, use of ca opt isn't required as it is included in the chain"

echo " "
echo "Tidy tmp"
#rm -R tmp

# ------------- Client ------------- #
# Need one of these for each client  #
# ---------------------------------- #

echo " "
echo "Create a public key in case you want a client to be able to encrypt messages to this server."
echo "  Not required for simply accessing SSL/TLS web pages"
openssl rsa -pubout \
  -in  server/privkey.pem \
  -out client/server-pubkey.pem

#echo "Copy root ca cert to client as chain.pem"
#rsync -a ca/my-private-root-ca.cert.pem client/chain.pem

echo " "
echo "Create DER format crt for iOS Mobile Safari, etc"
openssl x509 \
	-outform der \
	-in  ca/my-private-root-ca.cert.pem \
	-out client/my-private-root-ca.crt

echo " "
echo " "
echo "You can now import client/my-private-root-ca.crt"
echo "  to client devices to make them recognise the private CA"
echo "The CA cert is also available in the certificate the server sends to the client."
echo " "
echo "**********************************************************************************"
echo "* The CA cert must be imported to every client's trusted root certificate store. *"
echo "**********************************************************************************"
echo " "
echo " "

# ------------- TESTING ------------- #
# Test your HTTPS effortlessly
#npm -g install serve-https
#serve-https --servername example.com --cert server/fullchain.pem --key certs/server/privkey.pem

# You can debug the certificate chain with openssl:
#openssl s_client -showcerts -connect example.com:443 -servername example.com
#openssl s_client -showcerts -connect 127.0.0.1:1880 -servername 192.168.1.167

# ------------- How to use --------- #
# Use in Windows
# Simply import the CA Cert (./ca/my-private-root-ca.cert.pem) into the Trusted Root Cert Auth using the certificates snapin in mmc

# In Node-RED's settings.js, use the following:
#
# FIRSTLY: npm install ssl-root-cas --save
#
#
#    // See http://nodejs.org/api/https.html#https_https_createserver_options_requestlistener
#	 // http://qugstart.com/blog/node-js/install-comodo-positivessl-certificate-with-node-js/
#	 // http://www.benjiegillam.com/2012/06/node-dot-js-ssl-certificate-chain/
#    https: {
#        key: fs.readFileSync( path.join('.', '.data', 'certs', 'server', 'privkey.pem') ),
#        cert: fs.readFileSync( path.join('.', '.data', 'certs', 'server', 'cert.pem') ),
#		 ca: fs.readFileSync( path.join('.', '.data', 'certs', 'server', 'fullchain.pem') ),
#    },

### EOF ###
