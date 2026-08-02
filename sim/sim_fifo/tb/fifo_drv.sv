`timescale 1ns/1ps

class fifo_drv #( parameter
    DW              = 16,
    DEPTH           = 4,
    CW              = 3,
    CASE_ID         = 0,
    DUT_TYPE        = 0,
    CYCLE_N         = 2000,
    SEED            = 32'h1234_5678,
    ALLOW_FULL_BYP  = 0
);

virtual fifo_if #(DW,CW).drv vif;

logic [DW-1:0] scb_mem [0:DEPTH-1];
integer        scb_wr_ptr;
integer        scb_rd_ptr;
integer        scb_count;
logic [31:0]   rand_state;
logic [31:0]   data_cnt;

function new(virtual fifo_if #(DW,CW).drv vif);
    this.vif = vif;
endfunction

function automatic logic [31:0] next_rand(input logic [31:0] cur);
    next_rand = {cur[30:0], cur[31] ^ cur[21] ^ cur[1] ^ cur[0]};
endfunction

task automatic scb_reset;
begin
    scb_wr_ptr = 0;
    scb_rd_ptr = 0;
    scb_count  = 0;
end
endtask

task automatic drive_idle;
begin
    vif.drv_cb.clear     <= 1'b0;
    vif.drv_cb.i_wr_en   <= 1'b0;
    vif.drv_cb.i_wr_data <= '0;
    vif.drv_cb.i_rd_en   <= 1'b0;
end
endtask

task automatic check_status;
begin
    if( vif.drv_cb.o_wr_full !== (scb_count==DEPTH) ) begin
        $fatal(1, "CASE%0d full mismatch: dut=%0b exp=%0b count=%0d",
               CASE_ID, vif.drv_cb.o_wr_full, (scb_count==DEPTH), scb_count);
    end
    if( vif.drv_cb.o_rd_empty !== (scb_count==0) ) begin
        $fatal(1, "CASE%0d empty mismatch: dut=%0b exp=%0b count=%0d",
               CASE_ID, vif.drv_cb.o_rd_empty, (scb_count==0), scb_count);
    end
    if( vif.drv_cb.o_water_level !== CW'(DEPTH-scb_count) ) begin
        $fatal(1, "CASE%0d water_level mismatch: dut=%0d exp=%0d count=%0d",
               CASE_ID, vif.drv_cb.o_water_level, (DEPTH-scb_count), scb_count);
    end
end
endtask

task automatic reset_phase;
begin
    rand_state = SEED;
    data_cnt   = 32'h1;
    scb_reset();
    drive_idle();
    vif.drv_cb.rst_n <= 1'b0;
    repeat(5) @(vif.drv_cb);
    vif.drv_cb.rst_n <= 1'b1;
    repeat(2) @(vif.drv_cb);
    check_status();
end
endtask

task automatic run_cycle(input integer cyc);
    integer        clear_fire;
    integer        wr_fire;
    integer        rd_fire;
    integer        want_wr;
    integer        want_rd;
    integer        clear_cmd;
    integer        wr_cmd;
    integer        rd_cmd;
    logic [DW-1:0] wr_data_cmd;
    logic [DW-1:0] wr_data_fire;
begin
    @(vif.drv_cb);

    clear_cmd = (cyc==CYCLE_N/2);
    wr_cmd    = 1'b0;
    rd_cmd    = 1'b0;
    if( clear_cmd ) begin
        wr_cmd = 1'b0;
        rd_cmd = 1'b0;
    end
    else begin
        rand_state  = next_rand(rand_state);
        want_wr     = rand_state[7:0] < 8'd155;
        rand_state  = next_rand(rand_state);
        want_rd     = rand_state[15:8] < 8'd145;

        rd_cmd = want_rd && (scb_count > 0);
        wr_cmd = want_wr && ((scb_count < DEPTH) || (ALLOW_FULL_BYP && rd_cmd));
    end
    wr_data_cmd  = data_cnt[DW-1:0] ^ (CASE_ID << 8);
    vif.drv_cb.clear     <= clear_cmd;
    vif.drv_cb.i_wr_en   <= wr_cmd;
    vif.drv_cb.i_rd_en   <= rd_cmd;
    vif.drv_cb.i_wr_data <= wr_data_cmd;

    if( rd_cmd && (vif.drv_cb.o_rd_data !== scb_mem[scb_rd_ptr]) ) begin
        $fatal(1, "CASE%0d data mismatch cycle=%0d dut=0x%0h exp=0x%0h count=%0d",
               CASE_ID, cyc, vif.drv_cb.o_rd_data, scb_mem[scb_rd_ptr], scb_count);
    end

    clear_fire  = clear_cmd;
    wr_fire     = wr_cmd;
    rd_fire     = rd_cmd;
    wr_data_fire = wr_data_cmd;

    @(vif.drv_cb);
    drive_idle();
    if( clear_fire ) begin
        scb_reset();
    end
    else begin
        if( wr_fire ) begin
            scb_mem[scb_wr_ptr] = wr_data_fire;
            scb_wr_ptr = (scb_wr_ptr+1) % DEPTH;
            data_cnt = data_cnt + 1'b1;
        end
        if( rd_fire ) begin
            scb_rd_ptr = (scb_rd_ptr+1) % DEPTH;
        end
        scb_count = scb_count + wr_fire - rd_fire;
    end

    check_status();
end
endtask

task automatic run;
begin
    reset_phase();
    for( integer cyc=0; cyc<CYCLE_N; cyc=cyc+1 ) begin
        run_cycle(cyc);
    end
    @(vif.drv_cb);
    drive_idle();
    repeat(5) @(vif.drv_cb);
    $display("CASE%0d PASS dut_type=%0d depth=%0d dw=%0d", CASE_ID, DUT_TYPE, DEPTH, DW);
end
endtask

endclass
