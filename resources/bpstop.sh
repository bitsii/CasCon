#!/bin/bash
export PATH=$PATH:.
export CLASSPATH=""
ps -fe | grep "bpAppName BAM" | grep -v grep | awk '{$1=$1}1' | cut -d " " -f 2 | xargs -I{} kill -9 {}
