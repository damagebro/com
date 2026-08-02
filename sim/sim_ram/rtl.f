//--------------------------------------
//define
//--------------------------------------
+define+COM_MEM_CTRL_W=4
${COM_PATH}/com_define.sv

//--------------------------------------
//implement
//--------------------------------------
${COM_PATH}/impl_template/memory/rtl/model/com_tpram_reg.sv
${COM_PATH}/impl_template/memory/rtl/shell/com_spram_shell.sv

//--------------------------------------
//common
//--------------------------------------
${COM_PATH}/common/com_find_lsb_first_one.sv
${COM_PATH}/common/com_arbiter_rr.sv
${COM_PATH}/common/fifo/com_sync_fifo_reg.sv
${COM_PATH}/common/com_ram_arbiter.sv
${COM_PATH}/common/com_ram_adp_sp.sv
${COM_PATH}/common/com_ram_adp_rmw.sv
${COM_PATH}/common/com_ram_adp_2sp.sv
