//////////////////////////////////////////////////////////////////////////////
//
//  Description: Clock domain crossing synchronizer for static or gray-coded signal.
//
//  Authors:   wwq
//  Version:   2.0
//
//////////////////////////////////////////////////////////////////////////////

module com_cdc_sig #( parameter
    SYNC_S = 3, //by back-end suggest, freq>1.5G ? 4 : freq>1G ? 3 : 2
    DATA_W = 1
)
(
input  wire                     i_dst_clk           ,
input  wire                     i_dst_rst_n         ,
input  wire [DATA_W-1:0]        i_src_data          ,
output wire [DATA_W-1:0]        o_dst_data          //,
);
//localparam-----------------------------------------------------------------
//signal declare-------------------------------------------------------------
//statement------------------------------------------------------------------
`ifdef COM_CDC_AS_REG
    reg  [SYNC_S-1:0][DATA_W-1:0] r_sync_data;
    assign o_dst_data = r_sync_data[SYNC_S-1];
    always @(posedge i_dst_clk or negedge i_dst_rst_n) begin
        if( !i_dst_rst_n )
            r_sync_data <= '0;
        else
            r_sync_data <= {r_sync_data[SYNC_S-2:0],i_src_data};
    end
`else
    //assign o_dst_data from stdcell sync cell.
    // genvar gi;
    // for(gi=0; gi<DATA_W; gi++) begin
    //     macro_dsync sinst(
    //         .ck (oclk     ),
    //         .clb(orst_n   ),
    //         .d  (idata[gi]),
    //         .o  (odata[gi])
    //         );
    // end
    /* use stdcell dff */
    reg  [SYNC_S-1:0][DATA_W-1:0] r_sync_data;
    assign o_dst_data = r_sync_data[SYNC_S-1];
    always @(posedge i_dst_clk or negedge i_dst_rst_n) begin
        if( !i_dst_rst_n )
            r_sync_data <= '0;
        else
            r_sync_data <= {r_sync_data[SYNC_S-2:0],i_src_data};
    end
`endif

//report---------------------------------------------------------------------
// synopsys translate_off
`ifndef COM_REPORT_OFF
    `ifdef COM_CDC_AS_REG
        initial begin
            $warning("COM Warning: Use reg for cdc at %m");
        end
    `endif
`endif
// synopsys translate_on

endmodule //end of com_cdc_sig
