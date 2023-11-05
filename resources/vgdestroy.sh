#!/bin/bash
#multipass delete $1 2>/dev/null >/dev/null
#multipass purge

mkdir Vg
cd Vg
mkdir $1
cd $1

vagrant destroy -f

cd ..
rm -rf $1
cd ..
