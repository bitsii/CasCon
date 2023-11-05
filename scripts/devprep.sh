#!/bin/bash

export OSTYPE=`uname`

mkdir -p extlibs/jv
rm -f extlibs/jv/*
cd extlibs/jv

if [[ "$OSTYPE" == *"MINGW"* ]]; then
  echo "Mswin"
fi

if [ "$OSTYPE" == "Linux" ]; then
  echo "Linux"
fi

if [ "$OSTYPE" == "Darwin" ]; then
  echo "Macos"
fi

wget --tries=20 --timeout 20 --retry-connrefused https://repo1.maven.org/maven2/javax/servlet/javax.servlet-api/3.1.0/javax.servlet-api-3.1.0.jar
wget --tries=20 --timeout 20 --retry-connrefused https://repo1.maven.org/maven2/org/eclipse/jetty/aggregate/jetty-all/9.4.0.M1/jetty-all-9.4.0.M1-uber.jar
