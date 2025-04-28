#!/bin/bash

# Quick switch to launch the wallet by default instead while preserving
# the single entrypoint.
USE_WALLET_BINARY=${USE_WALLET_BINARY:=false}

# NOTE(canardleteer): Zano isn't quite yet aligned toward environment
#                     configuration (afaik), so I'm leaving just using
#                     a broken out script to figure out what I want.

if [ "${USE_WALLET_BINARY}" = true ]; then
    /usr/bin/simplewallet $@
else
    /usr/bin/zanod $@
fi

