#!/bin/bash
export PATH=$PATH:.
export CLASSPATH=""
cd ./App/BAM && (runwajvrs.sh --bpAppName BAM 2>&1 | split -b 10485760 - /tmp/bnapp$$.log) &
