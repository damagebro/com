
/******************************************************************************
*
*  Authors:   dmg
*    Email:   dmg@sensetime.com
*     Date:   2019/10/10-18:17:45
*
*  Description:
*  -
*
*  Modify:
*  -
*
******************************************************************************/


`ifndef com_pipe_ctrl_v
`define com_pipe_ctrl_v
module com_pipe_ctrl #( parameter
    NUM_PIPE = 2
)
(
input  wire                   clk               ,
input  wire                   rst_n             ,
input  wire                   clear             ,

input  wire                   ivld              ,
output wire                   irdy              ,
output wire                   ovld              ,
input  wire                   ordy              ,
output wire [NUM_PIPE-1:0]    pipe_upen         //, // pipeline[idx] update enable, idx0=ivld&&irdy
);
//localparam-----------------------------------------------------------------
integer i,j;
//reg  declare---------------------------------------------------------------
reg  [NUM_PIPE-1:0] arcb_busy;
//wire declare---------------------------------------------------------------
//statement------------------------------------------------------------------

reg  [NUM_PIPE-1:0] arb_in_hs ;
reg  [NUM_PIPE-1:0] arb_out_hs;
reg  [NUM_PIPE-1:0] arb_out_vld;
reg  [NUM_PIPE-1:0] arb_in_rdy;
always @(posedge clk or negedge rst_n)
begin
    if( !rst_n )
        arcb_busy <= 'b0;
    else if( clear )
        arcb_busy <= 'b0;
    else begin
        for( i=0; i<NUM_PIPE; i=i+1 )begin
            if( arb_in_hs[i] )
                arcb_busy[i] <= 1'b1;
            else if( arb_out_hs[i] )
                arcb_busy[i] <= 1'b0;
        end
    end
end

always @*
begin
    for( i=0; i<NUM_PIPE; i=i+1 )
        arb_out_vld[i] = arcb_busy[i];
end

wire [NUM_PIPE:0] abusy = {!ordy,arcb_busy};
always @*
begin
    arb_in_rdy = 'b0;
    for( i=0; i< NUM_PIPE; i=i+1 )
    for( j=i; j<=NUM_PIPE; j=j+1 )begin
        if( !abusy[j] )
            arb_in_rdy[i] = 1'b1; //spyglass disable W415a
    end //end of for i+j
end

wire [NUM_PIPE-1:0] ain_vld ;
wire [NUM_PIPE-1:0] aout_rdy;
generate
if(NUM_PIPE<2) begin:gen_PIPE_1   //spyglass disable W362
    assign ain_vld  = {ivld};
    assign aout_rdy = {ordy};
end
else begin:gen_PIPE_N
    assign ain_vld  = {arb_out_vld[NUM_PIPE-2:0],ivld};
    assign aout_rdy = {ordy,arb_in_rdy[NUM_PIPE-1:1]};
end
endgenerate

always @*
begin
    for( i=0; i<NUM_PIPE; i=i+1 ) begin
        arb_in_hs[i]  = ain_vld[i] && arb_in_rdy[i];
        arb_out_hs[i] = arb_out_vld[i] && aout_rdy[i];
    end
end

assign irdy = arb_in_rdy[0];
assign ovld= arb_out_vld[NUM_PIPE-1];
assign pipe_upen  = arb_in_hs;

endmodule //end of com_pipe_ctrl
`endif //end of com_pipe_ctrl_v
