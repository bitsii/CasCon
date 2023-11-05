#!/bin/bash

mkdir Vg
cd Vg
mkdir $3
cd $3
#vagrant init generic/ubuntu2004 2>/dev/null >/dev/null
cp ../../App/BAM/Vagrantfile . 2>/dev/null >/dev/null
vagrant up 2>/dev/null >/dev/null
