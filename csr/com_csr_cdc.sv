/******************************************************************************
*
*  Authors:   dmg
*    Email:   dmg@sensetime.com
*     Date:   2019/11/25-14:35:32
*
*  Description:
*  -
*
*  Modify:
*   2021/11/30: only 1 async_fifo from src to dst;
*               only 1 async_fifo from dst to src;
*
******************************************************************************/

//`include "com_asyncfifo_reg.v"

`ifndef com_csr_cdc_v
`define com_csr_cdc_v
module com_csr_cdc #( parameter
    AW = 16,
    DW = 32,
    SW = DW/8
)
(
input  wire                     clk_s               ,
input  wire                     rst_n_s             ,
input  wire                     clear_s             ,
input  wire                     clk_d               ,
input  wire                     rst_n_d             ,
input  wire                     clear_d             ,

UniCSRIf.Slave                  CsrIf_S             ,
UniCSRIf.Master                 CsrIf_M             //,
);
//localparam-----------------------------------------------------------------
localparam AFIFO_DEPTH_S2D = 8;
localparam AFIFO_DEPTH_D2S = 2;
//reg  declare---------------------------------------------------------------
//wire declare---------------------------------------------------------------
wire                   S_CSRValid        ;
wire                   S_CSRReady        ;
wire                   S_bCSRWrite       ;
wire [AW-1:0]          S_CSRAddr         ;
wire [DW-1:0]          S_CSRRdData       ;
wire [DW-1:0]          S_CSRWrData       ;
wire [SW-1:0]          S_CSRWrStrb       ;

wire                   M_CSRValid        ;
wire                   M_CSRReady        ;
wire                   M_bCSRWrite       ;
wire [AW-1:0]          M_CSRAddr         ;
wire [DW-1:0]          M_CSRRdData       ;
wire [DW-1:0]          M_CSRWrData       ;
wire [SW-1:0]          M_CSRWrStrb       ;

assign S_CSRValid    = CsrIf_S.CSRValid  ;
assign S_bCSRWrite   = CsrIf_S.bCSRWrite ;
assign S_CSRAddr     = CsrIf_S.CSRAddr   ;
assign S_CSRWrData   = CsrIf_S.CSRWrData ;
assign S_CSRWrStrb   = CsrIf_S.CSRWrStrb ;
assign CsrIf_S.CSRReady    = S_CSRReady  ;
assign CsrIf_S.CSRRdData   = S_CSRRdData ;

assign CsrIf_M.CSRValid    = M_CSRValid    ;
assign CsrIf_M.bCSRWrite   = M_bCSRWrite   ;
assign CsrIf_M.CSRAddr     = M_CSRAddr     ;
assign CsrIf_M.CSRWrData   = M_CSRWrData   ;
assign CsrIf_M.CSRWrStrb   = M_CSRWrStrb   ;
assign M_CSRReady      = CsrIf_M.CSRReady  ;
assign M_CSRRdData     = CsrIf_M.CSRRdData ;
//statement------------------------------------------------------------------
reg  rc_csr_rdflag;
always @(posedge clk_s or negedge rst_n_s)
begin
    if( !rst_n_s )begin
        rc_csr_rdflag <= 1'b0;
    end
    else if( clear_s || (S_CSRValid&&S_CSRReady) )begin
        rc_csr_rdflag <= 1'b0;
    end
    else if( S_CSRValid && !S_bCSRWrite )begin
        rc_csr_rdflag <= 1'b1;
    end
end

wire                     awr_en     = S_bCSRWrite ? S_CSRValid && S_CSRReady : S_CSRValid && !rc_csr_rdflag;
wire [SW+DW+AW+1-1:0]    awr_data   = {S_CSRWrStrb,S_CSRWrData,S_CSRAddr,S_bCSRWrite};
wire                     ard_en     ;
wire [SW+DW+AW+1-1:0]    ard_data   ;
wire                     awr_full   ;
wire                     ard_empty  ;
com_async_fifo_reg #(
    .DW         ( SW+DW+AW+1      ), //8
    .DEPTH      ( AFIFO_DEPTH_S2D )  //4
)r_com_async_fifo_reg_s2d
(
    .wr_clk               ( clk_s                ), //i
    .wr_rst_n             ( rst_n_s              ), //i
    .wr_clear             ( clear_s              ), //i
    .rd_clk               ( clk_d                ), //i
    .rd_rst_n             ( rst_n_d              ), //i
    .rd_clear             ( clear_d              ), //i

    .wr_en                ( awr_en               ), //i
    .wr_data              ( awr_data             ), //i
    .wr_full              ( awr_full             ), //o
    .rd_en                ( ard_en               ), //i
    .rd_data              ( ard_data             ), //o
    .rd_empty             ( ard_empty            ), //o
    .water_level          (                      )  //o
);
assign ard_en = M_CSRValid && M_CSRReady;
assign M_CSRValid = !ard_empty;
assign {M_CSRWrStrb,M_CSRWrData,M_CSRAddr,M_bCSRWrite} = ard_data;

wire                     rd_wr_en    = M_CSRValid && M_CSRReady && !M_bCSRWrite;
wire [DW-1:0]            rd_wr_data  = M_CSRRdData;
wire                     rd_rd_en    ;
wire [DW-1:0]            rd_rd_data  ;
wire                     rd_wr_full  ;
wire                     rd_rd_empty ;
com_async_fifo_reg #(
    .DW         ( DW              ), //8
    .DEPTH      ( AFIFO_DEPTH_D2S )  //4
)r_com_async_fifo_reg_d2s
(
    .wr_clk               ( clk_d                ), //i
    .wr_rst_n             ( rst_n_d              ), //i
    .wr_clear             ( clear_d              ), //i
    .rd_clk               ( clk_s                ), //i
    .rd_rst_n             ( rst_n_s              ), //i
    .rd_clear             ( clear_s              ), //i

    .wr_en                ( rd_wr_en             ), //i
    .wr_data              ( rd_wr_data           ), //i
    .rd_en                ( rd_rd_en             ), //i
    .rd_data              ( rd_rd_data           ), //o
    .wr_full              ( rd_wr_full           ), //o
    .rd_empty             ( rd_rd_empty          ), //o
    .water_level          (                      )  //o
);
assign rd_rd_en = !rd_rd_empty;
assign S_CSRReady = S_bCSRWrite ? !awr_full : !rd_rd_empty;
assign S_CSRRdData= rd_rd_data;
//assert(RD_Full);

endmodule //end of com_csr_cdc
`endif //end of com_csr_cdc_v

