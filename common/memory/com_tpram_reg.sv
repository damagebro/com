//////////////////////////////////////////////////////////////////////////////
//
//  Description: unified reg-based ram
//
//
//////////////////////////////////////////////////////////////////////////////

module com_tpram_reg #(
    parameter DATA_W                   ,        // Data width of memory. No default value.
    parameter DEPTH                    ,        // Depth of memory. No default value.
    parameter BE_W      = 1            ,        // Byte enable width.
    parameter ADDR_W    = $clog2(DEPTH)         // Address width
    )(
    input                       wr_clk ,
    input   logic [  BE_W-1: 0] wr_en  ,
    input   logic [ADDR_W-1: 0] wr_addr,
    input   logic [DATA_W-1: 0] wr_data,

    input                       rd_clk ,
    input   logic               rd_en  ,
    input   logic [ADDR_W-1: 0] rd_addr,
    output  logic [DATA_W-1: 0] rd_data
    );

    localparam BYTE_W = DATA_W/BE_W;

    logic [DATA_W-1:0] regfile [DEPTH-1:0]/*synthesis syn_ramstyle="no_rw_check"*/;

    always@(posedge wr_clk)
    for(int i=0; i<BE_W; i++) if(wr_en[i]) begin
        regfile[wr_addr][i*BYTE_W+:BYTE_W] <= wr_data[i*BYTE_W+:BYTE_W]; //spyglass disable ResetFlop-ML
    end

    always@(posedge rd_clk) if(rd_en) begin
        rd_data <= regfile[rd_addr]; //spyglass disable ResetFlop-ML
    end

endmodule
