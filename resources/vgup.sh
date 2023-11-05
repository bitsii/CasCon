#!/bin/bash
#multipass delete $1 2>/dev/null >/dev/null
#multipass purge

mkdir Vg
cd Vg
mkdir $1
cd $1

vagrant up

cd ..
cd ..
