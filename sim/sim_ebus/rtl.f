//--------------------------------------
//define
//--------------------------------------
$COM_PATH/com_define.sv
$IMPL_PATH/define/impl_define_sim.sv

//--------------------------------------
//impl
//--------------------------------------
//-f $IMPL_PATH/impl.f
$IMPL_PATH/memory/com_spram_shell.sv
$IMPL_PATH/memory/com_sprom_shell.sv
$IMPL_PATH/memory/com_tpram1ck_shell.sv
$IMPL_PATH/memory/com_tpram2ck_shell.sv
$IMPL_PATH/memory/com_tpram_reg.sv
$IMPL_PATH/stdcell/com_cdc_sig.sv
$IMPL_PATH/stdcell/com_clk_gate.sv

//--------------------------------------
//com
//--------------------------------------
-f $RTL_DIR/com/filelist/com_all.f

//--------------------------------------
//project
//--------------------------------------