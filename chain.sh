#!/bin/bash

DIR="$( which set-chain-env.sh)"
DIR="$(dirname $DIR)"

source   $DIR/cc.env.sh

INIT_REQUIRED=$CC2_INIT_REQUIRED
IS_INIT=$CC2_INIT_REQUIRED

OPERATION=$1
case $OPERATION in
    "check")
        OPERATION="checkcommitreadiness"
        ;;
    "approve")
        OPERATION="approveformyorg"
        ;;
    "help")
        usage
        exit 0
esac
SHOW_CMD="show"

OPTIND=$((OPTIND+1))

while getopts "npohj" OPTION; do
    case $OPTION in 
        p)  
            if [ "$OPERATION" != "install" ]; then
                echo "ERROR: Option -p may be used only with 'install'"
                exit 0
            fi
            
            OPERATION="pinstall"
            ;;
        o)  
            SHOW_CMD="cmd"
            ;;

        n)  
            if [ "$OPERATION" != "instantiate" ] && [ "$OPERATION" != "checkcommitreadiness" ] && [ "$OPERATION" != "approveformyorg" ]; then
                echo "ERROR: Option -n may be used only with 'instantiate' | 'checkcommitreadiness' | 'approveformyorg'  | 'upgrade-auto' "
                exit 0
            fi
            CC2_INIT_REQUIRED="false"
            ;;

        j) 
           
            OUTPUT_FORMAT=" -O json "
            ;;
        h)  
            usage
            exit 0
            ;;
        
    esac
done


get-cc-installed.sh &> /dev/null
source $CC2_ENV_FOLDER/get-cc-installed &> /dev/null

function show_command_execute {
    if [ "$SHOW_CMD" == "show" ]; then
        echo $cmd
        echo
        eval $cmd
        return
    elif [ "$SHOW_CMD" == "cmd" ]; then
        echo $cmd
        echo
    else 
        eval $cmd
    fi
}



function update_properties {
    get-cc-info.sh &> /dev/null
    source $CC2_ENV_FOLDER/get-cc-info &> /dev/null


    case  "$CC2_ENDORSING_PEERS" in
        "auto")
            CC2_ENDORSING_PEERS="--peerAddresses=$CORE_PEER_ADDRESS"
            ;;
        "acme")
            CC2_ENDORSING_PEERS="--peerAddresses=acme-peer1.acme.com:7051"
            ;;
        "budget")
            CC2_ENDORSING_PEERS="--peerAddresses=budget-peer1.budget.com:8051"
            ;;
        "both")
            CC2_ENDORSING_PEERS="--peerAddresses=acme-peer1.acme.com:7051 --peerAddresses=budget-peer1.budget.com:8051"
            ;;
        *)
            CC2_ENDORSING_PEERS="--peerAddresses=$CORE_PEER_ADDRESS"
    esac
    if [ "$CC2_INIT_REQUIRED" == "true" ]; then
        INIT_REQUIRED="--init-required"
        IS_INIT="--isInit"
    else 
        INIT_REQUIRED=""
        IS_INIT=""
    fi
    SIG_POLICY=""
    if [ "$CC2_SIGNATURE_POLICY" != "" ]; then
        SIG_POLICY="--signature-policy \"$CC2_SIGNATURE_POLICY\""
    fi
    CHANNEL_CONFIG_POLICY=""
    if [ "$CC2_CHANNEL_CONFIG_POLICY" != "" ]; then
        CHANNEL_CONFIG_POLICY="--channel-config-policy \"$CC2_CHANNEL_CONFIG_POLICY\""
    fi
    PRIVATE_DATA_JSON=""
    if [ "$CC_PRIVATE_DATA_JSON" != "" ]; then
        PRIVATE_DATA_JSON="--collections-config $GOPATH/src/$CC_PATH/$CC_PRIVATE_DATA_JSON"
    fi
}


update_properties


function cc_package {

    if [ "$INSTALLED_MAX_LABEL_INTERNAL_VERSION" == "-1" ]; then 
        INTERNAL_DEV_VERSION=1
    else
       
        INTERNAL_DEV_VERSION=$((INSTALLED_MAX_LABEL_INTERNAL_VERSION+1))
    fi
 
    mkdir -p  $CC2_PACKAGE_FOLDER
    echo "==>Creating package: $CC2_PACKAGE_FOLDER/$CC_NAME.$CC_VERSION-$INTERNAL_DEV_VERSION.tar.gz"
    cmd="peer lifecycle chaincode package $CC2_PACKAGE_FOLDER/$CC_NAME.$CC_VERSION-$INTERNAL_DEV_VERSION.tar.gz -p $CC_PATH \
                --label="$CC_NAME.$CC_VERSION-$INTERNAL_DEV_VERSION" -l $CC_LANGUAGE"
    show_command_execute $cmd
}

# Install
function cc_install {


    if [ "$INSTALLED_MAX_LABEL_INTERNAL_VERSION" == "-1" ]; then 
        INTERNAL_DEV_VERSION=1
    else

        INTERNAL_DEV_VERSION=$((INSTALLED_MAX_LABEL_INTERNAL_VERSION+1))
    fi

    echo "==>Installing chaincode [$CC2_PACKAGE_FOLDER/$CC_NAME.$CC_VERSION-$INTERNAL_DEV_VERSION.tar.gz ---ON--- $CORE_PEER_ADDRESS]"
    
    cmd="peer lifecycle chaincode install  $CC2_PACKAGE_FOLDER/$CC_NAME.$CC_VERSION-$INTERNAL_DEV_VERSION.tar.gz"

    show_command_execute $cmd
}


function cc_approveformyorg {

    update_properties


    if [ "$INSTALLED_MAX_PACKAGE_ID" == "" ] ; then 
        if [ "$SHOW_CMD" != "cmd" ]; then
            echo "Package ID is '' - did you install the chain code with version=$CC_VERSION? check with chain.sh list"
            read -p 'Would you like to approve without install? (y/n) ? ' USER_RESPONSE
            if [ "$USER_RESPONSE" != "y" ]; then
                exit
            fi
        else
            echo "Package ID is '' as chain code $CC_NAME.$CC_VERSION Not Installed"
        fi
    fi


    APPROVAL_PENDING=true
    case "$ORGANIZATION_CONTEXT" in
        acme) 
              APPROVAL_DONE=$COMMITTED_APPROVAL_ACME
              ;;
        budget) 
              APPROVAL_DONE=$COMMITTED_APPROVAL_BUDGET
              ;;
    esac

    if [ "$COMMITTED_CC_SEQUENCE" != -1 ]; then 
        CC2_SEQUENCE_NEW=$((COMMITTED_CC_SEQUENCE+1))
    else 
        CC2_SEQUENCE_NEW="1"
    fi

    if [ "$APPROVAL_DONE" == "true" ] && [ "$CC2_SEQUENCE" != "$CC2_SEQUENCE_NEW" ]; then
        echo "Specified Sequence different from actual $CC2_SEQUENCE != $CC2_SEQUENCE_NEW "
        read -p  "Would you like to  proceed? (y/n) " USER_RESPONSE
        if [ "$USER_RESPONSE" != "y" ]; then
            exit
        fi
    fi

    echo "==>Approving for $ORGANIZATION_CONTEXT : [Seq#$CC2_SEQUENCE   $INIT_REQUIRED ]"
    cmd="peer lifecycle chaincode approveformyorg --channelID $CC_CHANNEL_ID  --name $CC_NAME \
         --version $CC_VERSION --package-id $INSTALLED_MAX_PACKAGE_ID --sequence $CC2_SEQUENCE \
         $INIT_REQUIRED  $PRIVATE_DATA_JSON  -o $ORDERER_ADDRESS $SIG_POLICY $CHANNEL_CONFIG_POLICY \
         $CC2_ENDORSING_PEERS --waitForEvent"

    show_command_execute $cmd

}


function cc_commit {
    echo "==>Committing for $ORGANIZATION_CONTEXT : [$CC_CHANNEL_ID $CC_NAME.$CC_VERSION  Seq#$CC2_SEQUENCE   $INIT_REQUIRED on $CC2_ENDORSING_PEERS]"
    cmd="peer lifecycle chaincode commit -C $CC_CHANNEL_ID -n $CC_NAME -v $CC_VERSION \
         --sequence $CC2_SEQUENCE  $INIT_REQUIRED    $PRIVATE_DATA_JSON  \
            $SIG_POLICY $CHANNEL_CONFIG_POLICY $CC2_ENDORSING_PEERS --waitForEvent"

    show_command_execute $cmd
}

# Init
function cc_init {
    echo "==>Initializing  -C $CC_CHANNEL_ID -n $CC_NAME"
    cmd="peer chaincode invoke  -C $CC_CHANNEL_ID -n $CC_NAME -c '$CC_CONSTRUCTOR' \
    --waitForEvent $IS_INIT -o $ORDERER_ADDRESS \
    $CC2_ENDORSING_PEERS"

    show_command_execute $cmd
}

function cc_invoke {
    # invoke
    cmd="peer chaincode invoke -C $CC_CHANNEL_ID -n $CC_NAME  -c '$CC_INVOKE_ARGS' -o $ORDERER_ADDRESS \
     --waitForEvent \
     $CC2_ENDORSING_PEERS"

     show_command_execute $cmd
}

# List
function cc_list {
    echo "Chaincode Installed on: [$CORE_PEER_ADDRESS]"
    echo "============================================"
    cmd="peer lifecycle chaincode queryinstalled"
    show_command_execute $cmd

    echo ""
    echo "==========================================="
    cmd="peer lifecycle chaincode querycommitted -C $CC_CHANNEL_ID -n $CC_NAME "

    show_command_execute $cmd
}

function cc_install_auto {

    echo "NOT supported in 2.0 and above!!   use  > chain.sh install -p"
    exit

    if [ "$INSTALLED_MAX_LABEL_VERSION" == "-1" ]; then 
        $INSTALLED_MAX_LABEL_VERSION_NEW="1.0"
    else 
        INSTALLED_MAX_LABEL_VERSION_NEW=${INSTALLED_MAX_LABEL_VERSION%.*}
        INSTALLED_MAX_LABEL_VERSION_NEW=$((INSTALLED_MAX_LABEL_VERSION_NEW+1))
    fi
    INSTALLED_MAX_LABEL_VERSION_NEW="$INSTALLED_MAX_LABEL_VERSION_NEW".0

    set-chain-env.sh -v $INSTALLED_MAX_LABEL_VERSION_NEW

    source   $DIR/cc.env.sh

    echo "Chaincode Packaging & Installation: [$CC_NAME $CC_VERSION]"
    echo "============================================="

    cc_pinstall

}


function cc_upgrade_auto {

    cc_pinstall

    get-cc-info.sh  &> /dev/null
    source $CC2_ENV_FOLDER/get-cc-info &> /dev/null


    if [ "$COMMITTED_CC_SEQUENCE" == "-1" ]; then
      COMMITTED_CC_SEQUENCE=1
    else
      COMMITTED_CC_SEQUENCE=$((COMMITTED_CC_SEQUENCE+1))
    fi

    if [ "$SHOW_CMD" != "cmd" ]; then
        set-chain-env.sh -s $COMMITTED_CC_SEQUENCE
        source   $DIR/cc.env.sh
    fi

    cc_instantiate
}


function cc_instantiate {

    cc_approveformyorg
  
    cc_commit
  
    if [ $CC2_INIT_REQUIRED == "true" ]; then
        cc_init
    fi
}


function cc_pinstall {
    cc_package

    cc_install
}


if [ -z $OPERATION ];
then
    usage
elif  [ "$OPERATION" == "list" ]; then
    # List
    cc_list

elif  [ "$OPERATION" == "upgrade-auto" ]; then
    cc_upgrade_auto
elif  [ "$OPERATION" == "package" ]; then
    # Package
    cc_package

elif  [ "$OPERATION" == "install" ]
then
    cc_install

elif [ "$OPERATION" == "install-auto" ]; then

    cc_install_auto

elif  [ "$OPERATION" == "queryinstalled" ]
then
    echo "Installed on: [$CORE_PEER_ADDRESS]"
    cmd="peer lifecycle chaincode queryinstalled"

    show_command_execute $cmd

elif  [ "$OPERATION" == "approveformyorg" ]; then
    
    cc_approveformyorg

elif  [ "$OPERATION" == "checkcommitreadiness" ]; then

    cmd="peer lifecycle chaincode checkcommitreadiness -C $CC_CHANNEL_ID -n \
    $CC_NAME --sequence $CC2_SEQUENCE -v $CC_VERSION  $INIT_REQUIRED $SIG_POLICY  \
    $PRIVATE_DATA_JSON  "
    show_command_execute $cmd

elif  [ "$OPERATION" == "commit" ]; then
# Commit

    cc_commit

    
elif  [ "$OPERATION" == "querycommitted" ]; then
# Querycommitted
    cmd="peer lifecycle chaincode querycommitted $OUTPUT_FORMAT -C $CC_CHANNEL_ID -n $CC_NAME "

    show_command_execute $cmd

elif  [ "$OPERATION" == "init" ]; then
    cc_init

elif  [ "$OPERATION" == "query" ]; then
# query
    cmd="peer chaincode query -C $CC_CHANNEL_ID -n $CC_NAME -c '$CC_QUERY_ARGS' "

    show_command_execute $cmd

elif  [ "$OPERATION" == "invoke" ]; then
    cc_invoke
elif  [ "$OPERATION" == "instantiate" ]; then
    
    cc_instantiate

elif [ "$OPERATION" == "pinstall" ]; then
    cc_pinstall
else
    usage
    echo "Invalid operation!!!"
fi