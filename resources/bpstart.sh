#!/bin/bash
export PATH=$PATH:.
export CLASSPATH=""
cd ./App/CasCon && (runwajvrs.sh --bpAppName CasCon 2>&1 | split -b 10485760 - /tmp/casconapp$$.log) &
