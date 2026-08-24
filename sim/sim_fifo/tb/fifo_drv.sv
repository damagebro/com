`timescale 1ns/1ps

module fifo_drv #( parameter
    DW              = 16,
    DEPTH           = 4,
    CW              = 3,
    CASE_ID         = 0,
    DUT_TYPE        = 0,
    CYCLE_N         = 2000,
    SEED            = 32'h1234_5678,
    ALLOW_FULL_BYP  = 0
)
(
    fifo_if    fifo_bus,
    output reg o_done
);

//signal declare-------------------------------------------------------------
reg [DW-1:0] r_scb_mem [0:DEPTH-1];
integer      r_scb_wr_ptr;
integer      r_scb_rd_ptr;
integer      r_scb_count;
reg [31:0]   r_rand_state;
reg [31:0]   r_data_cnt;

function automatic [31:0] F_next_rand(input [31:0] cur);
    F_next_rand = {cur[30:0], cur[31]^cur[21]^cur[1]^cur[0]};
endfunction

task automatic T_scb_reset;
begin
    r_scb_wr_ptr = 0;
    r_scb_rd_ptr = 0;
    r_scb_count  = 0;
end
endtask

task automatic T_drive_idle;
begin
    fifo_bus.drv_cb.clear     <= 1'b0;
    fifo_bus.drv_cb.i_wr_en   <= 1'b0;
    fifo_bus.drv_cb.i_wr_data <= '0;
    fifo_bus.drv_cb.i_rd_en   <= 1'b0;
end
endtask

task automatic T_check_status;
begin
    if( fifo_bus.mon_cb.o_wr_full !== ((r_scb_count==DEPTH) &&
              !(ALLOW_FULL_BYP && fifo_bus.i_rd_en)) ) begin
        $fatal(1, "CASE%0d full mismatch: dut=%0b exp=%0b count=%0d",
               CASE_ID, fifo_bus.mon_cb.o_wr_full,
               ((r_scb_count==DEPTH) &&
                !(ALLOW_FULL_BYP && fifo_bus.i_rd_en)),
               r_scb_count);
    end
    if( (DUT_TYPE<4) &&
        (fifo_bus.mon_cb.o_rd_empty !== (r_scb_count==0)) ) begin
        $fatal(1, "CASE%0d empty mismatch: dut=%0b exp=%0b count=%0d",
               CASE_ID, fifo_bus.mon_cb.o_rd_empty,
               (r_scb_count==0), r_scb_count);
    end
    if( (DUT_TYPE>=4) && (r_scb_count==0) &&
        !fifo_bus.mon_cb.o_rd_empty ) begin
        $fatal(1, "CASE%0d empty mismatch: dut=%0b exp=1 count=%0d",
               CASE_ID, fifo_bus.mon_cb.o_rd_empty, r_scb_count);
    end
    if( fifo_bus.mon_cb.o_water_level !== CW'(DEPTH-r_scb_count) ) begin
        $fatal(1, "CASE%0d water_level mismatch: dut=%0d exp=%0d count=%0d",
               CASE_ID, fifo_bus.mon_cb.o_water_level,
               (DEPTH-r_scb_count), r_scb_count);
    end
end
endtask

task automatic T_apply_hs(input integer cyc);
begin
    if( fifo_bus.clear ) begin
        T_scb_reset();
    end
    else begin
        if( fifo_bus.i_rd_en &&
            (fifo_bus.mon_cb.o_rd_data !== r_scb_mem[r_scb_rd_ptr]) ) begin
            $fatal(1,
                   "CASE%0d data mismatch cycle=%0d dut=0x%0h exp=0x%0h count=%0d",
                   CASE_ID, cyc, fifo_bus.mon_cb.o_rd_data,
                   r_scb_mem[r_scb_rd_ptr], r_scb_count);
        end
        if( fifo_bus.i_wr_en ) begin
            r_scb_mem[r_scb_wr_ptr] = fifo_bus.i_wr_data;
            r_scb_wr_ptr = (r_scb_wr_ptr+1) % DEPTH;
            r_data_cnt = r_data_cnt + 1'b1;
        end
        if( fifo_bus.i_rd_en ) begin
            r_scb_rd_ptr = (r_scb_rd_ptr+1) % DEPTH;
        end
        r_scb_count = r_scb_count + fifo_bus.i_wr_en - fifo_bus.i_rd_en;
    end
end
endtask

task automatic T_drive_next(input integer cyc);
    reg          clear_cmd;
    reg          wr_cmd;
    reg          rd_cmd;
    reg          want_wr;
    reg          want_rd;
    reg [DW-1:0] wr_data_cmd;
begin
    clear_cmd = (cyc==CYCLE_N/2);
    wr_cmd    = 1'b0;
    rd_cmd    = 1'b0;
    if( !clear_cmd ) begin
        r_rand_state = F_next_rand(r_rand_state);
        want_wr      = r_rand_state[7:0] < 8'd155;
        r_rand_state = F_next_rand(r_rand_state);
        want_rd      = r_rand_state[15:8] < 8'd145;
        rd_cmd       = want_rd && (r_scb_count>0) &&
                       !fifo_bus.drv_cb.o_rd_empty;
        wr_cmd       = want_wr && ((r_scb_count<DEPTH) ||
                       (ALLOW_FULL_BYP && rd_cmd));
    end
    wr_data_cmd = r_data_cnt[DW-1:0] ^ DW'(CASE_ID << 8);
    fifo_bus.drv_cb.clear     <= clear_cmd;
    fifo_bus.drv_cb.i_wr_en   <= wr_cmd;
    fifo_bus.drv_cb.i_wr_data <= wr_data_cmd;
    fifo_bus.drv_cb.i_rd_en   <= rd_cmd;
end
endtask

integer cyc;

initial begin
    o_done             = 1'b0;
    fifo_bus.rst_n     = 1'b0;
    fifo_bus.clear     = 1'b0;
    fifo_bus.i_wr_en   = 1'b0;
    fifo_bus.i_wr_data = '0;
    fifo_bus.i_rd_en   = 1'b0;
    r_rand_state       = SEED;
    r_data_cnt         = 32'h1;
    T_scb_reset();

    repeat(5) @(fifo_bus.drv_cb);
    fifo_bus.drv_cb.rst_n <= 1'b1;
    repeat(2) @(fifo_bus.drv_cb);
    T_check_status();

    for( cyc=0; cyc<CYCLE_N; cyc=cyc+1 ) begin
        @(fifo_bus.drv_cb);
        T_check_status();
        T_apply_hs(cyc);
        T_drive_next(cyc);
    end

    @(fifo_bus.drv_cb);
    T_check_status();
    T_apply_hs(cyc);
    T_drive_idle();
    @(fifo_bus.drv_cb);
    T_check_status();
    T_apply_hs(cyc);
    repeat(5) @(fifo_bus.drv_cb);
    $display("CASE%0d PASS dut_type=%0d depth=%0d dw=%0d",
             CASE_ID, DUT_TYPE, DEPTH, DW);
    o_done = 1'b1;
end

endmodule
