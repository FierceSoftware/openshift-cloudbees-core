#!/usr/bin/env bash

## This script pulls in SSL Certificates and spits em into the certificate store for Java

set -e
## set -x	## Uncomment for debugging

function testCert() {
  set +e
  (keytool -list -storepass changeit -keystore $1 -alias $2 2>&1 > /dev/null)
  if [[ $? -eq 0 ]]; then
    return 42
  fi
  set -e
}

## check for custom keystore
CUSTOM_TRUSTSTORE=$JENKINS_HOME/.cacerts

if [ ! -f "$CUSTOM_TRUSTSTORE/cacerts" ]; then
    echo "No local keystore found, creating..."
    mkdir -p $CUSTOM_TRUSTSTORE
    cp $JAVA_HOME/jre/lib/security/cacerts $CUSTOM_TRUSTSTORE
fi

chmod +w $CUSTOM_TRUSTSTORE/cacerts

echo ""
echo -e "Starting SSL Certificate import...\n"

for CERT in "$@"
do
  echo "Pulling SSL certificate for ${CERT}..."
  FILENAME=${CERT//":"/".p"}
  CERTNAME=${FILENAME//"."/"-"}
  #echo "Q" | openssl s_client -connect ${CERT} 2>/dev/null | sed -ne '/-BEGIN CERTIFICATE-/,/-END CERTIFICATE-/p' > /tmp/$FILENAME.pem
  keytool -printcert -rfc -sslServer ${CERT} > /tmp/$FILENAME.pem
  echo "Checking if certificate exists in keystore..."
  testCert $CUSTOM_TRUSTSTORE/cacerts $CERTNAME
  if [ $? -eq 42 ]; then
    echo "Certificate already exists, skipping..."
  else
    echo "Certificate not in keystore, importing..."
    keytool -import -noprompt -storepass changeit -file /tmp/$FILENAME.pem -alias $CERTNAME -keystore $CUSTOM_TRUSTSTORE/cacerts
  fi
  echo ""
done

chmod -w $CUSTOM_TRUSTSTORE/cacerts
echo -e "Finished importing certificates!\n"