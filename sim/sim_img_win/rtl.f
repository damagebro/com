//--------------------------------------
//define
//--------------------------------------
$RTL_DIR/com/impl_template/impl_define_sim.sv
$RTL_DIR/com/common/com_define.sv

//--------------------------------------
//impl
//--------------------------------------
$COM_PATH/impl_template/memory/com_spram_cell.sv
$COM_PATH/impl_template/memory/com_sprom_cell.sv
$COM_PATH/impl_template/memory/com_tpram1ck_cell.sv
$COM_PATH/impl_template/memory/com_tpram2ck_cell.sv
$COM_PATH/impl_template/stdcell/com_cdc_sig.sv
$COM_PATH/impl_template/stdcell/com_clk_gate.sv

//--------------------------------------
//com
//--------------------------------------
-f $RTL_DIR/com/common/com_common.f
//-f $RTL_DIR/com/csr/com_csr.f
-f $RTL_DIR/com/emi/com_emi.f
-f $RTL_DIR/com/img/com_img.f

//--------------------------------------
//project
//--------------------------------------
