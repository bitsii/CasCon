#!/bin/bash

export OSTYPE=`uname`


if [[ $OSTYPE == *"MINGW"* ]]; then
  #echo "Is Mingw"
  export OSTYPE="Mingw"
fi

if [ "$OSTYPE" == "Darwin" ]; then
  cd extlibs/jv
  zip -r ../../../apprun/App/CasCon/extlibs.zip *
  cd ../..
fi

if [ "$OSTYPE" == "Linux" ]; then
  cd extlibs/jv
  zip -r ../../../apprun/App/CasCon/extlibs.zip *
  cd ../..
fi

if [ "$OSTYPE" == "Mingw" ]; then
  cd extlibs/jv
  zip -r ../../../apprun/App/CasCon/extlibs.zip *
  cd ../..
fi
