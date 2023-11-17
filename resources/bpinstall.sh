#!/bin/bash

export PATH=$PATH:/usr/bin:/usr/local/bin:/sbin:/usr/sbin:/usr/local/sbin:.

export OSTYPE=`uname`

echo "Getting required additional application software"
cp App/BBridge/javax.servlet-api-*.jar App/CasCon
cp App/BBridge/jetty-all-*-uber.jar App/CasCon

cd App/CasCon
unzip -o extlibs.zip
cd ../..

if [ "$OSTYPE" == "Linux" ]; then
  
  echo "Is Linux"

fi

echo "Done with bpinstall for CasCon"

echo ""
