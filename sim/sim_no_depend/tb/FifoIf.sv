interface FifoIf(
    input clk
);
    import FifoPkg::*;

    logic                     wr_en               ;
    logic [FIFO_DW-1:0]       wr_data             ;
    logic                     wr_full             ;
    logic                     rd_en               ;
    logic [FIFO_DW-1:0]       rd_data             ;
    logic                     rd_empty            ;


    clocking cb @ (posedge clk);
        output wr_en,wr_data, rd_en;
        input  wr_full, rd_data,rd_empty;
    endclocking
    modport tx(clocking cb);
endinterface //FifoIf

typedef virtual FifoIf.tx vFifoIf;