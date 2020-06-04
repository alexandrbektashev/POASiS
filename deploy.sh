#!/bin/bash

.    set-env.sh    acme
set-chain-env.sh       -n esp -v 1.0   -p  exercise/esp32   
chain.sh install -p

set-chain-env.sh        -c   '{"Args":["init","token","64", "MyToken,"esp32"]}'
chain.sh  instantiate
