#!/bin/bash

cd "${0%/*}"

cd ../../apprun/App

#cat CasCon/runParamsWa.txt | grep -v bindAddress | grep -v 127 > rpwt

#echo "--webApp.CasCon.app.port" >> rpwt
#echo "3200" >> rpwt

#cp rpwt CasCon/runParamsWa.txt
#cp rpwt CasCon/runParamsWaBr.txt
#rm rpwt

cp -f CasCon/runParamsHa.txt CasCon/runParamsWa.txt

rm -f CasCon.tar.gz

tar -czvf CasCon.tar.gz CasCon


