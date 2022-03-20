//FifoIf ------------------------------------------------------------
interface FifoIf #( parameter DW=32, DEPTH=8 )
(
    input clk
);
    localparam AW    = $clog2(DEPTH>2?DEPTH:2);

    logic                wr_en               ;
    logic [DW-1:0]       wr_data             ;
    logic                wr_full             ;
    logic                rd_en               ;
    logic [DW-1:0]       rd_data             ;
    logic                rd_empty            ;


    clocking cb @ (posedge clk);
        output wr_en,wr_data, rd_en;
        input  wr_full, rd_data,rd_empty;
    endclocking
    // modport tx(clocking cb);
endinterface //FifoIf
// typedef virtual FifoIf vFifoIf;


//AFifoIf ------------------------------------------------------------
interface AFifoIf(
    input wr_clk, rd_clk
);
    parameter  DW    = 16;
    parameter  DEPTH = 8;
    localparam AW    = $clog2(DEPTH>2?DEPTH:2);

    logic                wr_en               ;
    logic [DW-1:0]       wr_data             ;
    logic                wr_full             ;
    logic                rd_en               ;
    logic [DW-1:0]       rd_data             ;
    logic                rd_empty            ;


    clocking wcb @ (posedge wr_clk);
        output wr_en,wr_data;
        input  wr_full;
    endclocking
    clocking rcb @ (posedge rd_clk);
        output rd_en;
        input  rd_data,rd_empty;
    endclocking
endinterface //AFifoIf
// typedef virtual AFifoIf vAFifoIf;