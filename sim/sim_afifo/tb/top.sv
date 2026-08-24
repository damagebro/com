`timescale 1ns/1ps

`ifndef AFIFO_CASE_SEL
`define AFIFO_CASE_SEL -1
`endif

module top;

localparam CASE_SEL = `AFIFO_CASE_SEL;

wire [3:0] case_done;

if( CASE_SEL<0 || CASE_SEL==0 ) begin:gen_case0_enable
afifo_case #(
    .DUT_TYPE   ( 0             ),
    .CASE_ID    ( 0             ),
    .DW         ( 8             ),
    .DEPTH      ( 5             ),
    .SYNC_S     ( 2             ),
    .WR_HALF_NS ( 4             ),
    .RD_HALF_NS ( 7             ),
    .SEED       ( 32'h1357_2468 )
)u_case
(
    .o_done ( case_done[0] )
);
end
else begin:gen_case0_disable
    assign case_done[0] = 1'b1;
end

if( CASE_SEL<0 || CASE_SEL==1 ) begin:gen_case1_enable
afifo_case #(
    .DUT_TYPE   ( 1             ),
    .CASE_ID    ( 1             ),
    .DW         ( 8             ),
    .DEPTH      ( 5             ),
    .SYNC_S     ( 2             ),
    .WR_HALF_NS ( 4             ),
    .RD_HALF_NS ( 7             ),
    .SEED       ( 32'h2468_1357 )
)u_case
(
    .o_done ( case_done[1] )
);
end
else begin:gen_case1_disable
    assign case_done[1] = 1'b1;
end

if( CASE_SEL<0 || CASE_SEL==2 ) begin:gen_case2_enable
afifo_case #(
    .DUT_TYPE   ( 0             ),
    .CASE_ID    ( 2             ),
    .DW         ( 9             ),
    .DEPTH      ( 8             ),
    .SYNC_S     ( 3             ),
    .WR_HALF_NS ( 7             ),
    .RD_HALF_NS ( 4             ),
    .SEED       ( 32'h55aa_00ff )
)u_case
(
    .o_done ( case_done[2] )
);
end
else begin:gen_case2_disable
    assign case_done[2] = 1'b1;
end

if( CASE_SEL<0 || CASE_SEL==3 ) begin:gen_case3_enable
afifo_case #(
    .DUT_TYPE   ( 1             ),
    .CASE_ID    ( 3             ),
    .DW         ( 9             ),
    .DEPTH      ( 8             ),
    .SYNC_S     ( 3             ),
    .WR_HALF_NS ( 7             ),
    .RD_HALF_NS ( 4             ),
    .SEED       ( 32'h00ff_55aa )
)u_case
(
    .o_done ( case_done[3] )
);
end
else begin:gen_case3_disable
    assign case_done[3] = 1'b1;
end

initial begin
    if( !(CASE_SEL==-1 || (CASE_SEL>=0 && CASE_SEL<=3)) )
        $fatal(1, "invalid AFIFO_CASE_SEL=%0d", CASE_SEL);
end

initial begin
    #2000000;
    $fatal(1, "sim timeout");
end

`ifdef DUMP_FST
initial begin
    $dumpfile("run.fst");
    $dumpvars(0, top);
end
`endif

initial begin
    wait(&case_done);
    #20;
    $display("SIM_AFIFO PASS");
    $finish;
end

endmodule
