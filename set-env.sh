#!/bin/bash




DIR="$( which $BASH_SOURCE)"
DIR="$(dirname $DIR)"

export BINS_FOLDER=$DIR

source $DIR/to_absolute_path.sh

to-absolute-path $DIR
DIR=$ABS_PATH

# echo "-->$DIR"
export FABRIC_CFG_PATH="$DIR/../config"
to-absolute-path $FABRIC_CFG_PATH
FABRIC_CFG_PATH=$ABS_PATH


# export ORDERER_ADDRESS=localhost:7050
export ORDERER_ADDRESS=orderer.acme.com:7050

ORG_NAME=$1
if [ -z $ORG_NAME ];
then
    usage                            
    echo "Please provide the ORG Name!!!"
elif [ "$ORG_NAME" = "acme" ];
then
    # echo "Switching the Org = $ORG_NAME"
    # export CORE_PEER_ADDRESS=localhost:7051
    export CORE_PEER_ADDRESS=acme-peer1.acme.com:7051
elif [ "$ORG_NAME" = "budget" ];
then
    # echo "Switching the Org = $ORG_NAME"
    # export CORE_PEER_ADDRESS=localhost:8051
    export CORE_PEER_ADDRESS=budget-peer1.budget.com:8051
else
    usage                            
    echo "INVALID ORG Name!!!"
fi
export CORE_PEER_ID=$ORG_NAME-peer1.$ORG_NAME.com

CRYPTO_CONFIG_ROOT_FOLDER=$DIR/../crypto/crypto-config/peerOrganizations
export CORE_PEER_MSPCONFIGPATH=$CRYPTO_CONFIG_ROOT_FOLDER/$ORG_NAME.com/users/Admin@$ORG_NAME.com/msp
to-absolute-path $CORE_PEER_MSPCONFIGPATH
CORE_PEER_MSPCONFIGPATH=$ABS_PATH

MSP_ID="$(tr '[:lower:]' '[:upper:]' <<< ${ORG_NAME:0:1})${ORG_NAME:1}"
export CORE_PEER_LOCALMSPID=$MSP_ID"MSP"

if [ -z "$FABRIC_LOGGING_SPEC" ]; then
    export FABRIC_LOGGING_SPEC=info
fi

export ORGANIZATION_CONTEXT=$1


echo "# Environment in use"   > $DIR/env.sh
echo "export CORE_PEER_LOCALMSPID=$CORE_PEER_LOCALMSPID" >> $DIR/env.sh
echo "export CORE_PEER_MSPCONFIGPATH=$CORE_PEER_MSPCONFIGPATH" >> $DIR/env.sh
echo "export CORE_PEER_ID=$CORE_PEER_ID" >> $DIR/env.sh
# echo "export CORE_LOGGING_LEVEL=$CORE_LOGGING_LEVEL" >> $DIR/env.sh
echo "export FABRIC_LOGGING_SPEC=$FABRIC_LOGGING_SPEC" >> $DIR/env.sh
echo "export CORE_PEER_ADDRESS=$CORE_PEER_ADDRESS" >> $DIR/env.sh
echo "export ORDERER_ADDRESS=$ORDERER_ADDRESS" >> $DIR/env.sh
echo "export FABRIC_CFG_PATH=$FABRIC_CFG_PATH" >> $DIR/env.sh

# it has the '.'
if [[ $0 = *"set-env.sh" ]]
then
    echo "Did you use the . before ./set-env.sh? If yes then we are good :)"
fi