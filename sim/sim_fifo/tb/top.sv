`timescale 1ns/1ps

`ifndef FIFO_CASE_SEL
`define FIFO_CASE_SEL -1
`endif

module top;

localparam CASE_SEL = `FIFO_CASE_SEL;

wire case0_done;
wire case1_done;
wire case2_done;
wire case3_done;
wire case4_done;
wire case5_done;
wire [3:0] case6_done;
wire [3:0] case7_done;
wire [3:0] case8_done;

if( CASE_SEL<0 || CASE_SEL==0 ) begin:gen_case0_enable
fifo_basic_case #(
    .DUT_TYPE ( 0             ),
    .CASE_ID  ( 0             ),
    .DW       ( 16            ),
    .DEPTH    ( 4             ),
    .CYCLE_N  ( 2000          ),
    .SEED     ( 32'h1357_2468 )
)u_case0_fifo_reg_d4
(
    .o_done ( case0_done )
);
end
else begin:gen_case0_disable
    assign case0_done = 1'b1;
end

if( CASE_SEL<0 || CASE_SEL==1 ) begin:gen_case1_enable
fifo_basic_case #(
    .DUT_TYPE ( 0             ),
    .CASE_ID  ( 1             ),
    .DW       ( 17            ),
    .DEPTH    ( 5             ),
    .CYCLE_N  ( 2000          ),
    .SEED     ( 32'h2468_1357 )
)u_case1_fifo_reg_d5
(
    .o_done ( case1_done )
);
end
else begin:gen_case1_disable
    assign case1_done = 1'b1;
end

if( CASE_SEL<0 || CASE_SEL==2 ) begin:gen_case2_enable
fifo_basic_case #(
    .DUT_TYPE ( 1             ),
    .CASE_ID  ( 2             ),
    .DW       ( 16            ),
    .DEPTH    ( 4             ),
    .CYCLE_N  ( 2000          ),
    .SEED     ( 32'h55aa_00ff )
)u_case2_fifo_reg_v2_d4
(
    .o_done ( case2_done )
);
end
else begin:gen_case2_disable
    assign case2_done = 1'b1;
end

if( CASE_SEL<0 || CASE_SEL==3 ) begin:gen_case3_enable
fifo_basic_case #(
    .DUT_TYPE ( 1             ),
    .CASE_ID  ( 3             ),
    .DW       ( 17            ),
    .DEPTH    ( 5             ),
    .CYCLE_N  ( 2000          ),
    .SEED     ( 32'h00ff_55aa )
)u_case3_fifo_reg_v2_d5
(
    .o_done ( case3_done )
);
end
else begin:gen_case3_disable
    assign case3_done = 1'b1;
end

if( CASE_SEL<0 || CASE_SEL==4 ) begin:gen_case4_enable
fifo_basic_case #(
    .DUT_TYPE ( 2             ),
    .CASE_ID  ( 4             ),
    .DW       ( 16            ),
    .DEPTH    ( 4             ),
    .CYCLE_N  ( 2000          ),
    .SEED     ( 32'h1234_abcd )
)u_case4_fifo_reg_pfetch_d4
(
    .o_done ( case4_done )
);
end
else begin:gen_case4_disable
    assign case4_done = 1'b1;
end

if( CASE_SEL<0 || CASE_SEL==5 ) begin:gen_case5_enable
fifo_basic_case #(
    .DUT_TYPE       ( 3             ),
    .CASE_ID        ( 5             ),
    .DW             ( 16            ),
    .DEPTH          ( 4             ),
    .CYCLE_N        ( 2000          ),
    .SEED           ( 32'habcd_1234 ),
    .ALLOW_FULL_BYP ( 1             )
)u_case5_fifo_reg_fullbyp_d4
(
    .o_done ( case5_done )
);
end
else begin:gen_case5_disable
    assign case5_done = 1'b1;
end

for( genvar gi=0; gi<4; gi=gi+1 ) begin:gen_case6_fifo_ram_1p1bank
    localparam RAM_DELAY = gi+1;
    localparam OUT_DEPTH = RAM_DELAY+3;

    if( CASE_SEL<0 || CASE_SEL==10+gi ) begin:gen_enable
    fifo_basic_case #(
        .DUT_TYPE     ( 4                      ),
        .CASE_ID      ( 10+gi                  ),
        .DW           ( 16                     ),
        .DEPTH        ( 8+OUT_DEPTH            ),
        .RAM_DEPTH    ( 8                      ),
        .OUT_DEPTH    ( OUT_DEPTH              ),
        .RAM_RD_DELAY ( RAM_DELAY              ),
        .CYCLE_N      ( 3000                   ),
        .SEED         ( 32'h8765_4321+gi       )
    )u_case
    (
        .o_done ( case6_done[gi] )
    );
    end
    else begin:gen_disable
        assign case6_done[gi] = 1'b1;
    end
end

for( genvar gi=0; gi<4; gi=gi+1 ) begin:gen_case7_fifo_ram_1p2bank
    localparam RAM_DELAY = gi+1;
    localparam OUT_DEPTH = RAM_DELAY+3;

    if( CASE_SEL<0 || CASE_SEL==20+gi ) begin:gen_enable
    fifo_basic_case #(
        .DUT_TYPE     ( 5                      ),
        .CASE_ID      ( 20+gi                  ),
        .DW           ( 16                     ),
        .DEPTH        ( 8+OUT_DEPTH            ),
        .RAM_DEPTH    ( 8                      ),
        .OUT_DEPTH    ( OUT_DEPTH              ),
        .RAM_RD_DELAY ( RAM_DELAY              ),
        .CYCLE_N      ( 3000                   ),
        .SEED         ( 32'h4321_8765+gi       )
    )u_case
    (
        .o_done ( case7_done[gi] )
    );
    end
    else begin:gen_disable
        assign case7_done[gi] = 1'b1;
    end
end

for( genvar gi=0; gi<4; gi=gi+1 ) begin:gen_case8_fifo_ram_2p1ck
    localparam RAM_DELAY = gi+1;
    localparam OUT_DEPTH = RAM_DELAY+2;

    if( CASE_SEL<0 || CASE_SEL==30+gi ) begin:gen_enable
    fifo_basic_case #(
        .DUT_TYPE     ( 6                      ),
        .CASE_ID      ( 30+gi                  ),
        .DW           ( 16                     ),
        .DEPTH        ( 8+OUT_DEPTH            ),
        .RAM_DEPTH    ( 8                      ),
        .OUT_DEPTH    ( OUT_DEPTH              ),
        .RAM_RD_DELAY ( RAM_DELAY              ),
        .CYCLE_N      ( 3000                   ),
        .SEED         ( 32'h1122_3344+gi       )
    )u_case
    (
        .o_done ( case8_done[gi] )
    );
    end
    else begin:gen_disable
        assign case8_done[gi] = 1'b1;
    end
end

initial begin
    if( !(CASE_SEL==-1 || (CASE_SEL>=0 && CASE_SEL<=5) ||
          (CASE_SEL>=10 && CASE_SEL<=13) ||
          (CASE_SEL>=20 && CASE_SEL<=23) ||
          (CASE_SEL>=30 && CASE_SEL<=33)) ) begin
        $fatal(1, "invalid FIFO_CASE_SEL=%0d", CASE_SEL);
    end
end

initial begin
    #1000000;
    $fatal(1, "sim timeout");
end

`ifdef DUMP_FST
initial begin
    $dumpfile("run.fst");
    $dumpvars(0, top);
end
`endif

initial begin
    wait( case0_done && case1_done && case2_done &&
          case3_done && case4_done && case5_done &&
          (&case6_done) && (&case7_done) && (&case8_done) );
    #20;
    $display("SIM_FIFO PASS");
    $finish;
end

endmodule
