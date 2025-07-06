/******************************************************************************
*
*  Authors:   dmg
*    Email:   dmg@sensetime.com
*     Date:   2025/07/05-21:55:05
*
*  Description:
*   valid-only pipeline with data;
*
*  Modify:
*  -
*
******************************************************************************/

module com_pipe_data_vlds #( parameter
    PIPE_NUM = 1, //range=[1:]
    DW       = 8  //range=[1:]
)
(
input  wire                     clk                 ,
input  wire                     rst_n               ,
input  wire                     clear               ,

input  wire [DW-1:0]            idat                ,
input  wire                     ivld                ,
output wire                     irdy                ,
output wire [DW-1:0]            odat                ,
output wire                     ovld                ,
input  wire                     ordy                //,
);
//localparam-----------------------------------------------------------------
//signal declare-------------------------------------------------------------
wire [PIPE_NUM-1:0] pipe_upen;
reg  [PIPE_NUM-1:0][DW-1:0] r_vld_buf;
//statement------------------------------------------------------------------
assign odat = r_vld_buf[PIPE_NUM-1:0];

always @(posedge clk) begin
    if( pipe_upen[0] )
        r_vld_buf[0] <= idat;

    for( int i=1; i<PIPE_NUM; i++ )
        if( pipe_upen[i] )
            r_vld_buf[i] <= r_vld_buf[i-1];
end
com_pipe_ctrl_vlds #(
    .PIPE_NUM   ( PIPE_NUM   )  //2
)u_com_pipe_ctrl_vlds
(
    .clk                  ( clk                  ), //i
    .rst_n                ( rst_n                ), //i
    .clear                ( clear                ), //i

    .ivld                 ( ivld                 ), //i
    .irdy                 ( irdy                 ), //o
    .ovld                 ( ovld                 ), //o
    .ordy                 ( ordy                 ), //i
    .pipe_upen            ( pipe_upen            )  //o
);

endmodule //com_pipe_data_vlds

