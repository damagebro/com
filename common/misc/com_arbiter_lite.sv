
/******************************************************************************
*
*  Authors:   dmg
*    Email:   dmg@sensetime.com
*     Date:   2019/10/18-10:00:32
*
*  Description:
*  -
*
*  Modify:
*  -
*
******************************************************************************/


`ifndef com_arbiter_lite_v
`define com_arbiter_lite_v
module com_arbiter_lite #( parameter
    PORT_N = 2,
    MODE   = "round_from_small", //small_first, large_first, round_from_small, round_from_large, round_hold_small, round_hold_large
    PTID_W = $clog2(PORT_N<2?2:PORT_N)
)
(
input  wire                   clk               ,
input  wire                   rst_n             ,
input  wire                   clear             ,

input  wire [PORT_N-1:0]      requests          ,
output wire [PTID_W-1:0]      grant_id          //,
);
//localparam-----------------------------------------------------------------
localparam STR_MODE = MODE;
localparam NUM_CH = PORT_N;
localparam CH_DW  = PTID_W;
integer i;
//reg  declare---------------------------------------------------------------
//wire declare---------------------------------------------------------------
wire [CH_DW-1:0] const_max_ch = NUM_CH-1;
//statement------------------------------------------------------------------
reg  [CH_DW-1:0] idx;
reg  [CH_DW-1:0] rb_id;

generate
case(STR_MODE)
"small_first": begin:gen_small_first
    always @*
    begin
        rb_id = 'b0;
        for( i=0; i<NUM_CH; i=i+1 )begin
            idx = NUM_CH-1-i; //spyglass disable W415a
            if( requests[idx] )
                rb_id = idx; //spyglass disable W415a
        end
    end
end
"large_first": begin:gen_large_first
    always @*
    begin
        rb_id = 'b0;
        for( i=0; i<NUM_CH; i=i+1 )begin
            idx = i; //spyglass disable W415a
            if( requests[idx] )
                rb_id = idx; //spyglass disable W415a
        end
    end
end
"round_from_small": begin:gen_round_from_small
    reg  [CH_DW-1:0] rc_gnt;
    reg  [CH_DW-0:0] rb_tmp;
    reg  rb_find_flag;
    wire gnt_upen = rc_gnt!=rb_id && requests[rb_id];
    always @*
    begin
        rb_id = 'b0;
        rb_tmp = 'b0;
        rb_find_flag = 1'b0;
        for( i=0; i<NUM_CH; i=i+1 )begin
            rb_tmp = rc_gnt+i+1;  //spyglass disable W415a
            idx = rb_tmp < NUM_CH ? rb_tmp : (rb_tmp-NUM_CH); //spyglass disable W362,W415a
            if( requests[idx] && !rb_find_flag )begin
                rb_id = idx; //spyglass disable W415a
                rb_find_flag = 1'b1; //spyglass disable W415a
            end
        end
    end
    always @(posedge clk or negedge rst_n)
    begin
        if( !rst_n )
            rc_gnt <= const_max_ch; //spyglass disable NonConstReset-ML
        else if( clear )
            rc_gnt <= const_max_ch;
        else if( gnt_upen )
            rc_gnt <= rb_id;
    end
end:gen_round_from_small
"round_from_large": begin:gen_round_from_large
    reg  [CH_DW-1:0] rc_gnt;
    reg  [CH_DW-0:0] rb_tmp;
    reg  rb_find_flag;
    wire gnt_upen = rc_gnt!=rb_id && requests[rb_id];
    always @*
    begin
        rb_id = 'b0;
        rb_find_flag = 1'b0;
        for( i=0; i<NUM_CH; i=i+1 )begin
            rb_tmp = rc_gnt-i-1;
            idx = rb_tmp[CH_DW] ? $signed({1'b0,NUM_CH[CH_DW-1:0]})+$signed(rb_tmp) : rb_tmp; //spyglass disable W362,W415a
            if( requests[idx] && !rb_find_flag )begin
                rb_id = idx; //spyglass disable W415a
                rb_find_flag = 1'b1; //spyglass disable W415a
            end
        end
    end
    always @(posedge clk or negedge rst_n)
    begin
        if( !rst_n )
            rc_gnt <= 'b0;
        else if( clear )
            rc_gnt <= 'b0;
        else if( gnt_upen )
            rc_gnt <= rb_id;
    end
end:gen_round_from_large
"round_hold_small": begin:gen_round_hold_small
    reg  [CH_DW-1:0] rc_gnt;
    reg  [CH_DW-0:0] rb_tmp;
    reg  rb_find_flag;
    wire gnt_upen = rc_gnt!=rb_id && requests[rb_id];
    always @*
    begin
        rb_id = 'b0;
        rb_find_flag = 1'b0;
        rb_tmp = 'b0;
        for( i=0; i<NUM_CH; i=i+1 )begin
            rb_tmp = rc_gnt+i; //spyglass disable W415a
            idx = rb_tmp < NUM_CH ? rb_tmp : (rb_tmp-NUM_CH); //spyglass disable W362,W415a
            if( requests[idx] && !rb_find_flag )begin
                rb_id = idx; //spyglass disable W415a
                rb_find_flag = 1'b1; //spyglass disable W415a
            end
        end
    end
    always @(posedge clk or negedge rst_n)
    begin
        if( !rst_n ) begin
            rc_gnt <= 'b0;
        end
        else if( clear )begin
            rc_gnt <= 'b0;
        end
        else if( gnt_upen )begin
            rc_gnt <= rb_id;
        end
    end
end
"round_hold_large": begin:gen_round_hold_large
    reg  [CH_DW-1:0] rc_gnt;
    reg  [CH_DW-0:0] rb_tmp;
    reg  rb_find_flag;
    wire gnt_upen = rc_gnt!=rb_id && requests[rb_id];
    always @*
    begin
        rb_id = 'b0;
        rb_find_flag = 1'b0;
        for( i=0; i<NUM_CH; i=i+1 )begin
            rb_tmp = rc_gnt-i; //spyglass disable W415a
            idx = rb_tmp[CH_DW] ? $signed({1'b0,NUM_CH[CH_DW-1:0]})+$signed(rb_tmp) : rb_tmp; //spyglass disable W362,W415a
            if( requests[idx] && !rb_find_flag )begin
                rb_id = idx; //spyglass disable W415a
                rb_find_flag = 1'b1; //spyglass disable W415a
            end
        end
    end
    always @(posedge clk or negedge rst_n)
    begin
        if( !rst_n ) begin
            rc_gnt <= const_max_ch; //spyglass disable NonConstReset-ML
        end
        else if( clear )begin
            rc_gnt <= const_max_ch;
        end
        else if( gnt_upen )begin
            rc_gnt <= rb_id;
        end
    end
end
default: begin:gen_arb_no
    always @*
    begin
        rb_id = 'b0;
        for( i=0; i<NUM_CH; i=i+1 )begin
            idx = NUM_CH-1-i;
            if( requests[idx] )
                rb_id = idx;
        end
    end
end

endcase
endgenerate

assign grant_id = rb_id;

endmodule //end of com_arbiter_lite
`endif //end of com_arbiter_lite_v

