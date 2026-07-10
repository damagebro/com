SCP_PATH=`pwd`
export SIM_DIR=$SCP_PATH
export VER_DIR=$SCP_PATH/tb/

RTL_DIR=$SCP_PATH
while [ "$RTL_DIR" != "/" ] && [ ! -f "$RTL_DIR/com/com_define.sv" ]
do
    RTL_DIR=`dirname "$RTL_DIR"`
done

if [ ! -f "$RTL_DIR/com/com_define.sv" ]
then
    echo "ERROR: cannot find RTL_DIR from $SCP_PATH"
    return 1 2>/dev/null || exit 1
fi

export RTL_DIR
export COM_PATH=$RTL_DIR/com/
export IMPL_PATH=$RTL_DIR/com/impl_template/

if [ ! -d "./bin/" ]
then
    mkdir ./bin/
fi

echo "RTL_DIR=$RTL_DIR"
echo "SIM_DIR=$SIM_DIR"
