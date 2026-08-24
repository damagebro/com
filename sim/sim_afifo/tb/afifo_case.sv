`timescale 1ns/1ps

module afifo_case #( parameter
    DUT_TYPE   = 0,
    CASE_ID    = 0,
    DW         = 8,
    DEPTH      = 5,
    SYNC_S     = 2,
    WR_HALF_NS = 4,
    RD_HALF_NS = 7,
    CYCLE_N    = 1600,
    SEED       = 32'h1234_5678,
    localparam CW = $clog2(DEPTH+1)
)
(
output logic o_done
);

//signal declare-------------------------------------------------------------
logic          wr_clk;
logic          rd_clk;
logic [DW-1:0] r_scb_q[$];
logic [31:0]   r_wr_rand_state;
logic [31:0]   r_rd_rand_state;
logic [31:0]   r_data_cnt;
logic [DW-1:0] r_wr_data_sample;
logic [DW-1:0] r_rd_data_sample;
logic          r_wr_hs_sample;
logic          r_rd_hs_sample;
logic          r_stop_wr;
logic          r_stop_all;
logic          r_seen_full;
logic          r_seen_empty;
integer        r_phase;
integer        r_wr_count;
integer        r_rd_count;

afifo_if #(
    .DW ( DW ),
    .CW ( CW )
)afifo_bus
(
    .wr_clk ( wr_clk ),
    .rd_clk ( rd_clk )
);

function automatic [31:0] F_next_rand(input [31:0] cur);
    F_next_rand = {cur[30:0],cur[31]^cur[21]^cur[1]^cur[0]};
endfunction

function automatic [7:0] F_wr_threshold(input integer phase);
begin
    case( phase )
        0: F_wr_threshold = 8'd240;
        1: F_wr_threshold = 8'd170;
        2: F_wr_threshold = 8'd50;
        default: F_wr_threshold = 8'd0;
    endcase
end
endfunction

function automatic [7:0] F_rd_threshold(input integer phase);
begin
    case( phase )
        0: F_rd_threshold = 8'd12;
        1: F_rd_threshold = 8'd165;
        2: F_rd_threshold = 8'd235;
        default: F_rd_threshold = 8'd255;
    endcase
end
endfunction

task automatic T_check_wr_status;
begin
    if( afifo_bus.ckwr_drv_cb.o_water_level>CW'(DEPTH) ) begin
        $fatal(1, "CASE%0d water level overflow: wl=%0d depth=%0d",
               CASE_ID, afifo_bus.ckwr_drv_cb.o_water_level, DEPTH);
    end
    if( afifo_bus.ckwr_drv_cb.o_wr_full !==
        (afifo_bus.ckwr_drv_cb.o_water_level=='0) ) begin
        $fatal(1, "CASE%0d full/water level mismatch: full=%0b wl=%0d",
               CASE_ID, afifo_bus.ckwr_drv_cb.o_wr_full,
               afifo_bus.ckwr_drv_cb.o_water_level);
    end
end
endtask

//clock
initial begin
    wr_clk = 1'b0;
    forever #(WR_HALF_NS) wr_clk = ~wr_clk;
end

initial begin
    rd_clk = 1'b0;
    forever #(RD_HALF_NS) rd_clk = ~rd_clk;
end

//control
initial begin
    o_done             = 1'b0;
    afifo_bus.wr_rst_n = 1'b0;
    afifo_bus.rd_rst_n = 1'b0;
    r_stop_wr          = 1'b0;
    r_stop_all         = 1'b0;
    r_seen_full        = 1'b0;
    r_seen_empty       = 1'b0;
    r_phase            = 0;
    r_wr_count         = 0;
    r_rd_count         = 0;
    r_scb_q.delete();

    repeat(5) @(afifo_bus.ckwr_drv_cb);
    afifo_bus.ckwr_drv_cb.wr_rst_n <= 1'b1;
    repeat(4) @(afifo_bus.ckrd_drv_cb);
    afifo_bus.ckrd_drv_cb.rd_rst_n <= 1'b1;

    repeat(CYCLE_N/4) @(afifo_bus.ckwr_drv_cb);
    r_phase = 1;
    repeat(CYCLE_N/2) @(afifo_bus.ckwr_drv_cb);
    r_phase = 2;
    repeat(CYCLE_N/4) @(afifo_bus.ckwr_drv_cb);
    r_phase = 3;
    r_stop_wr = 1'b1;

    wait(r_scb_q.size()==0);
    wait(afifo_bus.o_rd_empty===1'b1);
    repeat(SYNC_S+3) @(afifo_bus.ckwr_drv_cb);
    r_stop_all = 1'b1;

    if( !r_seen_full )
        $fatal(1, "CASE%0d did not reach fifo full", CASE_ID);
    if( !r_seen_empty )
        $fatal(1, "CASE%0d did not reach fifo empty", CASE_ID);
    if( r_wr_count==0 || r_wr_count!=r_rd_count ) begin
        $fatal(1, "CASE%0d transaction count mismatch: wr=%0d rd=%0d",
               CASE_ID, r_wr_count, r_rd_count);
    end

    $display("CASE%0d PASS dut_type=%0d depth=%0d wr_half=%0d rd_half=%0d tx=%0d",
             CASE_ID, DUT_TYPE, DEPTH, WR_HALF_NS, RD_HALF_NS, r_wr_count);
    o_done = 1'b1;
end

//write driver and monitor
initial begin
    afifo_bus.i_wr_en   = 1'b0;
    afifo_bus.i_wr_data = '0;
    r_wr_rand_state     = SEED;
    r_data_cnt          = 32'h1;
    wait(afifo_bus.wr_rst_n);

    while( !r_stop_all ) begin
        @(afifo_bus.ckwr_drv_cb);
        r_wr_hs_sample = afifo_bus.i_wr_en &&
                         !afifo_bus.ckwr_drv_cb.o_wr_full;
        r_wr_data_sample = afifo_bus.i_wr_data;
        r_wr_rand_state = F_next_rand(r_wr_rand_state);
        if( r_wr_hs_sample )
            afifo_bus.ckwr_drv_cb.i_wr_en <= 1'b0;
        else begin
            afifo_bus.ckwr_drv_cb.i_wr_en <= !r_stop_wr &&
                !afifo_bus.ckwr_drv_cb.o_wr_full &&
                (r_wr_rand_state[7:0]<F_wr_threshold(r_phase));
            afifo_bus.ckwr_drv_cb.i_wr_data <=
                r_data_cnt[DW-1:0] ^ DW'(CASE_ID << 4);
        end
        if( r_wr_hs_sample ) begin
            r_scb_q.push_back(r_wr_data_sample);
            r_data_cnt = r_data_cnt + 1'b1;
            r_wr_count = r_wr_count + 1;
            if( (DUT_TYPE==0 && r_scb_q.size()>DEPTH+1) ||
                (DUT_TYPE==1 && r_scb_q.size()>DEPTH) ) begin
                $fatal(1, "CASE%0d logical capacity overflow: count=%0d",
                       CASE_ID, r_scb_q.size());
            end
        end
        if( afifo_bus.ckwr_drv_cb.o_wr_full )
            r_seen_full = 1'b1;
        T_check_wr_status();
    end
    afifo_bus.ckwr_drv_cb.i_wr_en <= 1'b0;
end

//read driver and monitor
initial begin
    afifo_bus.i_rd_en = 1'b0;
    r_rd_rand_state   = SEED ^ 32'ha5a5_5a5a;
    wait(afifo_bus.rd_rst_n);

    while( !r_stop_all ) begin
        @(afifo_bus.ckrd_drv_cb);
        r_rd_hs_sample = afifo_bus.i_rd_en &&
                         !afifo_bus.ckrd_drv_cb.o_rd_empty;
        r_rd_data_sample = afifo_bus.ckrd_drv_cb.o_rd_data;
        r_rd_rand_state = F_next_rand(r_rd_rand_state);
        if( r_rd_hs_sample )
            afifo_bus.ckrd_drv_cb.i_rd_en <= 1'b0;
        else
            afifo_bus.ckrd_drv_cb.i_rd_en <=
                !afifo_bus.ckrd_drv_cb.o_rd_empty &&
                (r_rd_rand_state[7:0]<F_rd_threshold(r_phase));
        if( r_rd_hs_sample ) begin
            if( r_scb_q.size()==0 )
                $fatal(1, "CASE%0d scoreboard underflow", CASE_ID);
            if( r_rd_data_sample!==r_scb_q[0] ) begin
                $fatal(1, "CASE%0d data mismatch: dut=0x%0h exp=0x%0h count=%0d",
                       CASE_ID, r_rd_data_sample, r_scb_q[0], r_scb_q.size());
            end
            void'(r_scb_q.pop_front());
            r_rd_count = r_rd_count + 1;
        end
        if( afifo_bus.ckrd_drv_cb.o_rd_empty )
            r_seen_empty = 1'b1;
    end
    afifo_bus.ckrd_drv_cb.i_rd_en <= 1'b0;
end

//instance
generate
if( DUT_TYPE==0 ) begin:gen_afifo
com_async_fifo_reg #(
    .DW     ( DW     ),
    .DEPTH  ( DEPTH  ),
    .SYNC_S ( SYNC_S )
)u_dut
(
    .wr_clk        ( afifo_bus.wr_clk        ),
    .wr_rst_n      ( afifo_bus.wr_rst_n      ),
    .rd_clk        ( afifo_bus.rd_clk        ),
    .rd_rst_n      ( afifo_bus.rd_rst_n      ),
    .i_wr_en       ( afifo_bus.i_wr_en       ),
    .i_wr_data     ( afifo_bus.i_wr_data     ),
    .o_wr_full     ( afifo_bus.o_wr_full     ),
    .i_rd_en       ( afifo_bus.i_rd_en       ),
    .o_rd_data     ( afifo_bus.o_rd_data     ),
    .o_rd_empty    ( afifo_bus.o_rd_empty    ),
    .o_water_level ( afifo_bus.o_water_level )
);
end
else begin:gen_afifo_exactwl
com_async_fifo_reg_exactwl #(
    .DW     ( DW     ),
    .DEPTH  ( DEPTH  ),
    .SYNC_S ( SYNC_S )
)u_dut
(
    .wr_clk        ( afifo_bus.wr_clk        ),
    .wr_rst_n      ( afifo_bus.wr_rst_n      ),
    .rd_clk        ( afifo_bus.rd_clk        ),
    .rd_rst_n      ( afifo_bus.rd_rst_n      ),
    .i_wr_en       ( afifo_bus.i_wr_en       ),
    .i_wr_data     ( afifo_bus.i_wr_data     ),
    .o_wr_full     ( afifo_bus.o_wr_full     ),
    .i_rd_en       ( afifo_bus.i_rd_en       ),
    .o_rd_data     ( afifo_bus.o_rd_data     ),
    .o_rd_empty    ( afifo_bus.o_rd_empty    ),
    .o_water_level ( afifo_bus.o_water_level )
);
end
endgenerate

endmodule
