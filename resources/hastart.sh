#!/bin/bash
export PATH=$PATH:.
export CLASSPATH=""
cd ./App/CasCon && (runwajvrs.sh --bpAppName CasCon 2>&1 | cat -) &
