#!/bin/bash

export PATH=$PATH:/usr/bin:/usr/local/bin:/sbin:/usr/sbin:/usr/local/sbin:.

echo "Getting required additional application software"
cp App/BBridge/javax.servlet-api-*.jar App/BAM
cp App/BBridge/jetty-all-*-uber.jar App/BAM

export OSTYPE=`uname`

if [ "$OSTYPE" == "Darwin" ]; then
  echo "macos"
  #interactive instructions - sudo
  #brew install virtualbox
  #brew install vagrant
fi

if [ "$OSTYPE" == "Linux" ]; then
  echo "linux"
  #sudo snap install multipass
  echo "Installing required additional system software"
  sudo apt -qq --assume-yes update
  sudo apt -qq --assume-yes install virtualbox vagrant
fi

#vagrant plugin install vagrant-scp

echo "Done with bpinstall for BAM"

echo ""
