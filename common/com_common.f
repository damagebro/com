$COM_PATH/common/com_define.sv

$COM_PATH/common/cdc/com_cdc_rstn.sv
$COM_PATH/common/cdc/com_cdc_pulse.sv
$COM_PATH/common/fifo/com_sync_fifo_ctrl.sv
$COM_PATH/common/fifo/com_sync_fifo_reg.sv
$COM_PATH/common/fifo/com_sync_fifo_ram_2p1ck.sv
$COM_PATH/common/fifo/com_sync_fifo_ram_1p2bank.sv
$COM_PATH/common/fifo/com_async_fifo_ctrl.sv    //not use afifo_ctrl separately, only used in afifo_reg, afifo_ram*;
$COM_PATH/common/fifo/com_async_fifo_reg.sv
$COM_PATH/common/fifo/com_async_fifo_ram_2p1ck.sv
$COM_PATH/common/fifo/com_async_fifo_ram_2p2ck.sv
$COM_PATH/common/fifo/com_dp_buffer.sv
$COM_PATH/common/fifo/com_dp_ram.sv
$COM_PATH/common/memory/com_tpram_reg.sv
$COM_PATH/common/memory/com_spram_mate.sv
$COM_PATH/common/memory/com_tpram1ck_mate.sv

$COM_PATH/common/misc/com_reg.sv
$COM_PATH/common/misc/com_reg_e.sv
$COM_PATH/common/misc/com_reg_ce.sv
$COM_PATH/common/misc/com_counter.sv
$COM_PATH/common/misc/com_edge_detect.sv
$COM_PATH/common/misc/com_arbiter_lite.sv
$COM_PATH/common/misc/com_pipe_ctrl.sv
$COM_PATH/common/misc/com_mimo.sv
$COM_PATH/common/misc/com_simo_no_delay.sv


//2025/7 new,
$COM_PATH/common/misc/new/com_arbiter_rr.sv
$COM_PATH/common/misc/new/com_find_tail1.sv
$COM_PATH/common/misc/new/com_pipe_ctrl_vlds.sv
$COM_PATH/common/misc/new/com_pipe_ctrl_vld.sv
$COM_PATH/common/misc/new/com_pipe_data_rdy.sv
$COM_PATH/common/misc/new/com_pipe_data_regslice.sv
$COM_PATH/common/misc/new/com_pipe_data_vlds.sv
