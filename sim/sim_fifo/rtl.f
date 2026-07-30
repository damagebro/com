//--------------------------------------
//define
//--------------------------------------
+define+COM_MEM_CTRL_W=4
${COM_PATH}/com_define.sv

//--------------------------------------
//implement (stdcell/sram)
//--------------------------------------
// AUTO_MEM_SHELL_FILELIST_BEGIN
${COM_PATH}/impl_template/memory/rtl/model/com_tpram_reg.sv
${COM_PATH}/impl_template/memory/rtl/shell/com_spram_shell.sv
${COM_PATH}/impl_template/memory/rtl/shell/com_tpram1ck_shell.sv
// AUTO_MEM_SHELL_FILELIST_END

//--------------------------------------
//project
//--------------------------------------
// AUTO_USER_FILELIST_BEGIN
${COM_PATH}/common/fifo/com_sync_fifo_reg.sv
${COM_PATH}/common/fifo/com_sync_fifo_reg_v2.sv
${COM_PATH}/common/fifo/com_sync_fifo_reg_pfetch.sv
${COM_PATH}/common/fifo/com_sync_fifo_reg_fullbyp.sv
${COM_PATH}/common/fifo/com_sync_fifo_reg_2w1r.sv
${COM_PATH}/common/fifo/com_sync_fifo_ram_1p1bank.sv
${COM_PATH}/common/fifo/com_sync_fifo_ram_1p2bank.sv
${COM_PATH}/common/fifo/com_sync_fifo_ram_2p1ck.sv
// AUTO_USER_FILELIST_END
