`timescale 1ns/1ps

module top;

wire case0_done;
wire case1_done;
wire case2_done;
wire case3_done;
wire case4_done;
wire case5_done;
wire case6_done;
wire case7_done;
wire case8_done;

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

fifo_basic_case #(
    .DUT_TYPE     ( 4             ),
    .CASE_ID      ( 6             ),
    .DW           ( 16            ),
    .DEPTH        ( 12            ),
    .RAM_DEPTH    ( 8             ),
    .OUT_DEPTH    ( 4             ),
    .RAM_RD_DELAY ( 1             ),
    .CYCLE_N      ( 3000          ),
    .SEED         ( 32'h8765_4321 )
)u_case6_fifo_ram_1p1bank
(
    .o_done ( case6_done )
);

fifo_basic_case #(
    .DUT_TYPE     ( 5             ),
    .CASE_ID      ( 7             ),
    .DW           ( 16            ),
    .DEPTH        ( 12            ),
    .RAM_DEPTH    ( 8             ),
    .OUT_DEPTH    ( 4             ),
    .RAM_RD_DELAY ( 1             ),
    .CYCLE_N      ( 3000          ),
    .SEED         ( 32'h4321_8765 )
)u_case7_fifo_ram_1p2bank
(
    .o_done ( case7_done )
);

fifo_basic_case #(
    .DUT_TYPE     ( 6             ),
    .CASE_ID      ( 8             ),
    .DW           ( 16            ),
    .DEPTH        ( 12            ),
    .RAM_DEPTH    ( 8             ),
    .OUT_DEPTH    ( 4             ),
    .RAM_RD_DELAY ( 1             ),
    .CYCLE_N      ( 3000          ),
    .SEED         ( 32'h1122_3344 )
)u_case8_fifo_ram_2p1ck
(
    .o_done ( case8_done )
);

initial begin
    #1000000;
    $fatal(1, "sim timeout");
end

initial begin
    wait( case0_done && case1_done && case2_done &&
          case3_done && case4_done && case5_done &&
          case6_done && case7_done && case8_done );
    #20;
    $display("SIM_FIFO PASS");
    $finish;
end

endmodule
