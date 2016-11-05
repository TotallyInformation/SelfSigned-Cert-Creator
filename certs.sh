#!/bin/bash

# Create self-signed certificates and keys for a CA and a server
# Primarily for using with SSL/TLS to secure communications
# between local servers and clients NOT ON THE INTERNET!
#
# Inspired by: https://github.com/Daplie/nodejs-self-signed-certificate-example/blob/master/make-root-ca-and-certificates.sh
#
# Use as: bash make-certs.sh 'localhost.daplie.com'
#
# Author: Julian Knight, Totally Information, 2016-11-05
# License: MIT, may be freely reused.

if [[ ! ${1+x} ]]; then
	echo "No FQDN parameter given - exiting"
	exit 1
else
	echo "FQDN is '$1'"
fi

FQDN=$1

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
  -subj "/C=UK/ST=South Yorks/L=Sheffield/O=Totally Information/CN=totallyinformation.net"

echo "Import ca/my-private-root-ca.cert.pem to Windows Trusted Root store if required" 

# ------------- Server ------------- #
# Need one of these for each server  #
# ---------------------------------- #

echo "Create a Server Private Key"
openssl genrsa \
  -out server/privkey.pem \
  2048

echo "Create a request from your Server, which your Root CA will sign"
# 1 for each domain such as 192.168.1.167, example.com, *.example.com, awesome.example.com
# NOTE: You MUST match CN to the domain name or ip address you want to use
# Multi-domain certs require the use of a configuration file and SubjectAltName
openssl req -new \
  -key  server/privkey.pem \
  -out  tmp/csr.pem \
  -subj "/C=UK/ST=South Yorks/L=Sheffield/O=Totally Information/CN=${FQDN}"

echo "Sign the request from Device with your Root CA, creates the actual cert"
openssl x509 \
  -CAcreateserial -req \
  -in    tmp/csr.pem \
  -CA    ca/my-private-root-ca.cert.pem \
  -CAkey ca/my-private-root-ca.privkey.pem \
  -out   server/cert.pem \
  -days  9999

# Create a combined pfx file for convenience
openssl pkcs12 -export \
	-certfile ca/my-private-root-ca.cert.pem \
	-inkey server/privkey.pem \
	-in server/cert.pem \
	-out server/cert.pfx \
	-name "Self-Signed Server Certificate"

echo "Copy root ca cert to server & client as chain.pem"
rsync -a ca/my-private-root-ca.cert.pem server/chain.pem
rsync -a ca/my-private-root-ca.cert.pem client/chain.pem
echo "Create a server full chain cert for SSL/TLS use"
cat server/cert.pem server/chain.pem > server/fullchain.pem

echo "Use in Node.JS as: sslOpts = { key: 'server/privkey.pem', cert: 'server/fullchain.pem' }"
echo "  as this is self-signed, use of ca opt isn't required as it is included in the chain"

echo "Tidy tmp"
rm -R tmp

# ------------- Client ------------- #
# Need one of these for each client  #
# ---------------------------------- #

# Create a public key in case you want a client to be able to encrypt messages to this server.
# Not required for SSL/TLS
openssl rsa -pubout \
  -in  server/privkey.pem \
  -out client/server-pubkey.pem

#echo "Copy root ca cert to client as chain.pem"
#rsync -a ca/my-private-root-ca.cert.pem client/chain.pem

echo "create DER format crt for iOS Mobile Safari, etc"
openssl x509 \
	-outform der \
	-in  ca/my-private-root-ca.cert.pem \
	-out client/my-private-root-ca.crt

echo "Import client/my-private-root-ca.crt"
echo " to client devices to make them recognise the private CA"

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
