/******************************************************************************
*
*  Authors:   dmg
*    Email:   dmg@sensetime.com
*     Date:   2021/12/03-13:56:35
*
*  Description:
*  -
*
*  Modify:
*  -
*
******************************************************************************/

module com_edge_detect #( parameter
    MODE = "pos" // "pos"|"posedge", "neg"|"negedge", "dual"|"dualedge"
)
(
input  wire                     clk                 ,
input  wire                     rst_n               ,

input  wire                     i_level             ,
output wire                     o_pulse             //,
);
//localparam-----------------------------------------------------------------
`COM_PARAM_ASSERT( MODE=="pos"||MODE=="posedge" || MODE=="neg"||MODE=="negedge" || MODE=="dual"||MODE=="dualedge", "illegal MODE" ); //spyglass disable W193
//signal declare-------------------------------------------------------------
reg  r_level;
//statement------------------------------------------------------------------
//body---
always @(posedge clk or negedge rst_n) begin
    if( !rst_n )
        r_level <= 1'b0;
    else
        r_level <= i_level;
end

wire pls_posedge = i_level && !r_level;
wire pls_negedge = !i_level && r_level;
wire pls_dualedge= i_level ^ r_level;

generate
    if( MODE=="pos" || MODE=="posedge" ) begin:gen_pos
        assign o_pulse = pls_posedge;
    end
    else if( MODE=="neg" || MODE=="negedge" ) begin:gen_neg
        assign o_pulse = pls_negedge;
    end
    else if( MODE=="dual" || MODE=="dualedge" ) begin:gen_dual
        assign o_pulse = pls_dualedge;
    end
    else begin:gen_err
        assign o_pulse = 1'b0;
    end
endgenerate

endmodule //end of com_edge_detect
