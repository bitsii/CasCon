#!/bin/bash
multipass delete $1 2>/dev/null >/dev/null
multipass purge
