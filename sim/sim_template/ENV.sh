SCP_PATH=`pwd`
export SIM_DIR=$SCP_PATH
export RTL_DIR=$SCP_PATH/../../../
export VER_DIR=$SCP_PATH/tb/
export TC_DIR=$SCP_PATH/tc/

export COM_PATH=$RTL_DIR/com/
export IMPL_PATH=$RTL_DIR/com/impl_template/

if [ ! -d "./bin/" ]
then
    mkdir ./bin/
fi

echo ${RTL_DIR}