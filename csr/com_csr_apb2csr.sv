/******************************************************************************
*
*  Authors:   dmg
*    Email:   dmg@sensetime.com
*     Date:   2019/11/25-16:46:34
*
*  Description:
*  -
*
*  Modify:
*  -
*
******************************************************************************/

`ifndef com_csr_apb2csr_v
`define com_csr_apb2csr_v
module com_csr_apb2csr #( parameter
    AW_APB = 32,
    DW_APB = 32,
    SW_APB = DW_APB/8,
    AW_CSR = 16,
    DW_CSR = DW_APB,
    SW_CSR = DW_CSR/8
)
(
input  wire                     PCLK                ,
input  wire                     PRESETn             ,

input  wire [AW_APB-1:0]        PADDR               ,
input  wire [2:0]               PPROT               , //3'b001, [0]normal/privileged, [1]secure/nonsecure, [2]data/instruction;  0/1
input  wire                     PSELx               ,
input  wire                     PENABLE             ,
input  wire                     PWRITE              ,
input  wire [DW_APB-1:0]        PWDATA              ,
input  wire [SW_APB-1:0]        PSTRB               ,

output wire                     PREADY              ,
output wire [DW_APB-1:0]        PRDATA              ,
output wire                     PSLVERR             ,

UniCSRIf.Master                 CsrIf_M             //,
);
//localparam-----------------------------------------------------------------
localparam ST_IDLE   = 3'b001,
           ST_SETUP  = 3'b010,
           ST_ACCESS = 3'b100;
//reg  declare---------------------------------------------------------------
reg  [2:0] rc_apb_sta;
reg  [2:0] rb_apb_sta_nxt;
//wire declare---------------------------------------------------------------
wire clk   = PCLK;
wire rst_n = PRESETn;
wire [AW_APB-1:0] apb_baseaddr = 32'h0000_0000;//<script_target>

wire                   CSRValid          ;
wire                   CSRReady          ;
wire                   bCSRWrite         ;
wire [AW_CSR-1:0]      CSRAddr           ;
wire [DW_CSR-1:0]      CSRRdData         ;
wire [DW_CSR-1:0]      CSRWrData         ;
wire [SW_CSR-1:0]      CSRWrStrb         ;
assign CsrIf_M.CSRValid    = CSRValid    ;
assign CsrIf_M.bCSRWrite   = bCSRWrite   ;
assign CsrIf_M.CSRAddr     = CSRAddr     ;
assign CsrIf_M.CSRWrData   = CSRWrData   ;
assign CsrIf_M.CSRWrStrb   = CSRWrStrb   ;
assign CSRReady      = CsrIf_M.CSRReady  ;
assign CSRRdData     = CsrIf_M.CSRRdData ;
//statement------------------------------------------------------------------
always @(posedge clk or negedge rst_n)
begin
    if( !rst_n )begin
        rc_apb_sta <= ST_IDLE;
    end
    else begin
        rc_apb_sta <= rb_apb_sta_nxt;
    end
end
always @*
begin
    case ( rc_apb_sta )
        ST_IDLE:begin
            if( PSELx && !PENABLE )
                rb_apb_sta_nxt = ST_SETUP;
            else
                rb_apb_sta_nxt = ST_IDLE;
        end
        ST_SETUP:begin
            if( PSELx )
                rb_apb_sta_nxt = PENABLE ? ST_ACCESS : ST_SETUP;
            else
                rb_apb_sta_nxt = ST_IDLE;
        end
        ST_ACCESS:begin
            if( PREADY )
                rb_apb_sta_nxt = ST_SETUP;
            else
                rb_apb_sta_nxt = ST_ACCESS;
        end
        default: rb_apb_sta_nxt= ST_IDLE;
    endcase
end

wire pin_valid = rb_apb_sta_nxt[1] && PSELx;
wire pout_valid= rb_apb_sta_nxt[2] || rc_apb_sta[2]&&PENABLE;
reg               pwrite_d ;
reg  [AW_APB-1:0] paddr_d  ;
always @(posedge clk or negedge rst_n)
begin
    if( !rst_n )begin
        pwrite_d <= 'b0;
        paddr_d  <= 'b0;
    end
    else if( pin_valid )begin
        pwrite_d <= PWRITE;
        paddr_d  <= PADDR ;
    end
end

wire [AW_APB-1:0] paddr_off0 = paddr_d - apb_baseaddr;
assign CSRValid  = pout_valid;
assign bCSRWrite = pwrite_d;
assign CSRAddr   = paddr_off0[AW_CSR-1:0];//assert(AW_APB>AW_CSR);
assign CSRWrData = PWDATA;
assign CSRWrStrb = PSTRB;

assign PREADY = CSRReady;
assign PRDATA = CSRRdData;
assign PSLVERR = 1'b0; //tie to 0

endmodule //end of com_csr_apb2csr
`endif //end of com_csr_apb2csr_v

