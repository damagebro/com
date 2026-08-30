//--------------------------------------
//define
//--------------------------------------
+define+COM_ASSERT_ON
${COM_PATH}/com_define.sv

//--------------------------------------
//implement
//--------------------------------------
${COM_PATH}/impl_template/stdcell/com_cdc_sig.sv

//--------------------------------------
//project
//--------------------------------------
${COM_PATH}/common/com_find_lsb_first_one.sv
${COM_PATH}/common/com_arbiter_rr.sv
${COM_PATH}/common/fifo/com_sync_fifo_reg.sv
${COM_PATH}/common/fifo/com_async_fifo_reg.sv
${COM_PATH}/csr/com_csr_regslice.sv
${COM_PATH}/csr/com_csr_apb2csr.sv
${COM_PATH}/csr/com_csr_ahb2csr.sv
${COM_PATH}/csr/com_csr_axil2csr.sv
${COM_PATH}/csr/com_csr2apb.sv
${COM_PATH}/csr/com_csr_cdc.sv
${COM_PATH}/csr/com_csr_arbiter.sv
${COM_PATH}/csr/com_csr_timeout.sv
