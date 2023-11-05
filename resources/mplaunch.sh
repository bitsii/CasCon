#!/bin/bash
multipass launch --name $3 --mem $1 --disk $2 20.04 2>/dev/null >/dev/null
