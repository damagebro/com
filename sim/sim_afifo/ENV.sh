#!/usr/bin/env bash
SCP_PATH=`pwd`
export SIM_DIR=$SCP_PATH
export COM_PATH=$(cd "$SIM_DIR/../.." && pwd)

if [ ! -d "./bin/" ]
then
    mkdir ./bin/
fi

echo "SIM_DIR=$SIM_DIR"
echo "COM_PATH=$COM_PATH"
