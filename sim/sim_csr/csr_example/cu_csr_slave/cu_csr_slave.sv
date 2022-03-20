/******************************************************************************
*
*  Authors:   dmg
*    Email:   dmg@sensetime.com
*     Date:   2020/11/09-10:07:43
*
*  Description:
*  -
*
*  Modify:
*  -
*
******************************************************************************/

`ifndef cu_csr_slave_v
`define cu_csr_slave_v
module cu_csr_slave #( parameter
    AW = 16,
    DW = 32,
    SW = DW/8
)
(
input  wire                     clk                 ,
input  wire                     rst_n               ,
input  wire                     clear               ,

UniCSRIf.Slave                  CsrIf_S             ,
//cu_sta
input  wire [31:0]              cu_sta_versionD               ,
//cu_cfg1
output wire [11:0]              cu_cfg1_ntid_xR               ,
output wire [11:0]              cu_cfg1_ntid_yR               ,
output wire [5:0]               cu_cfg1_ntid_zR               ,
//cu_cfg2
output wire [31:0]              cu_cfg2_nctaid_xR             ,
//cu_cfg3
output wire [31:0]              cu_cfg3_nctaid_yR             ,
//cu_cfg4
output wire [31:0]              cu_cfg4_nctaid_zR             ,
//cu_cfg5
output wire [21:0][31:0]        cu_cfg5_paramR                ,
//cu_cfg6
output wire [31:0]              cu_cfg6_warp_szR              ,
//cu_cfg7
output wire [31:0]              cu_cfg7_init_pcR              ,
//cu_cmd
output wire                     cu_cmd_kernel_startOEn        ,
output wire                     cu_cmd_kernel_startO          ,
//cu_dbg
input  wire [31:0]              cu_dbg_pc_valD                //,
);
//localparam-----------------------------------------------------------------
//reg  declare---------------------------------------------------------------
//wire declare---------------------------------------------------------------
wire                   CSRValid          ;
wire                   CSRReady          ;
wire                   bCSRWrite         ;
wire [AW-1:0]          CSRAddr           ;
wire [DW-1:0]          CSRRdData         ;
wire [DW-1:0]          CSRWrData         ;
wire [SW-1:0]          CSRWrStrb         ;
assign CSRValid    = CsrIf_S.CSRValid  ;
assign bCSRWrite   = CsrIf_S.bCSRWrite ;
assign CSRAddr     = CsrIf_S.CSRAddr   ;
assign CSRWrData   = CsrIf_S.CSRWrData ;
assign CSRWrStrb   = CsrIf_S.CSRWrStrb ;
assign CsrIf_S.CSRReady    = CSRReady  ;
assign CsrIf_S.CSRRdData   = CSRRdData ;

wire [AW-1:0] csr_offset_regs1_lo = 'h0   ;
wire [AW-1:0] csr_offset_regs1_hi = 'h404 ;
wire [AW-1:0] csr_offset_dmys1_lo = 'h404 ;

wire bcsr_regs1_sel = CSRValid && CSRAddr>=csr_offset_regs1_lo && CSRAddr<csr_offset_regs1_hi;
wire bcsr_dmys1_sel = CSRValid && CSRAddr>=csr_offset_dmys1_lo;
wire bcsr_regs_sel = bcsr_regs1_sel;

wire             CSRValid_regs  = bcsr_regs_sel ? CSRValid : 1'b0;
wire [AW-1:0]    CSRAddr_regs   = bcsr_regs_sel ? CSRAddr  : {AW{1'b0}};
wire             CSRReady_regs  ;
wire [DW-1:0]    CSRRdData_regs ;

//statement------------------------------------------------------------------

wire          CSRReady_dmy   = 1'b1;
wire [DW-1:0] CSRRdData_dmy  = {2{16'hdeaf}};
reg           rb_csr_ready;
reg  [DW-1:0] rb_csr_rddata;
always @*
begin
    if( bcsr_regs_sel )begin
        rb_csr_ready = CSRReady_regs;
        rb_csr_rddata= CSRRdData_regs;
    end
    else begin
        rb_csr_ready = CSRReady_dmy;
        rb_csr_rddata= CSRRdData_dmy;
    end
end
assign CSRReady = rb_csr_ready;
assign CSRRdData= rb_csr_rddata;

cu_csr_slave_reg #(
    .AW (AW),
    .DW (DW)
) u_cu_csr_slave_reg
(
    .clk                 ( clk                  ),
    .rst_n               ( rst_n                ),
    .clear               ( clear                ),

    .CSRValid            ( CSRValid_regs        ),
    .CSRReady            ( CSRReady_regs        ),
    .bCSRWrite           ( bCSRWrite            ),
    .CSRAddr             ( CSRAddr_regs         ),
    .CSRRdData           ( CSRRdData_regs       ),
    .CSRWrData           ( CSRWrData            ),
    .CSRWrStrb           ( CSRWrStrb            ),
    .cu_sta_versionD               ( cu_sta_versionD                ),
    .cu_cfg1_ntid_xR               ( cu_cfg1_ntid_xR                ),
    .cu_cfg1_ntid_yR               ( cu_cfg1_ntid_yR                ),
    .cu_cfg1_ntid_zR               ( cu_cfg1_ntid_zR                ),
    .cu_cfg2_nctaid_xR             ( cu_cfg2_nctaid_xR              ),
    .cu_cfg3_nctaid_yR             ( cu_cfg3_nctaid_yR              ),
    .cu_cfg4_nctaid_zR             ( cu_cfg4_nctaid_zR              ),
    .cu_cfg5_paramR                ( cu_cfg5_paramR                 ),
    .cu_cfg6_warp_szR              ( cu_cfg6_warp_szR               ),
    .cu_cfg7_init_pcR              ( cu_cfg7_init_pcR               ),
    .cu_cmd_kernel_startOEn        ( cu_cmd_kernel_startOEn         ),
    .cu_cmd_kernel_startO          ( cu_cmd_kernel_startO           ),
    .cu_dbg_pc_valD                ( cu_dbg_pc_valD                 )//,
);

endmodule //end of cu_csr_slave
`endif //end of cu_csr_slave_v