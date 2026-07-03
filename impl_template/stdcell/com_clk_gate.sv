//////////////////////////////////////////////////////////////////////////////
//
//  Description: Clock Gating Control.
//
//  Authors:   wwq
//  Version:   2.0
//////////////////////////////////////////////////////////////////////////////

module com_clk_gate(
    input  wire i_ckg_en,
    input  wire i_clk,
    output wire o_clk
    );

`ifdef COM_FPGA
    assign o_clk = i_clk;
`else
    `ifdef COM_CLKGATE_AS_LATCH
        reg w_ckg_en;
        always @ ( i_clk or i_ckg_en )
        if ( ~i_clk )
            w_ckg_en = i_ckg_en;
        assign o_clk = i_clk & w_ckg_en;

    `else
        // pmu_clk_gate ginst(
        //     .CK (i_clk ),
        //     .E  (i_ckg_en ),
        //     .TE (1'b0 ),
        //     .QCK(o_clk )
        //     );

        /* use stdcell clk gate */
    `endif
`endif

//------------------------------------------------------------------------------
// Report & Assertion.
//------------------------------------------------------------------------------
// synopsys translate_off
`ifndef COM_REPORT_OFF
    `ifdef COM_CLKGATE_AS_LATCH
        initial begin
            $warning("COM Warning: Use latch as clk gate at %m");
        end
    `endif
`endif
// synopsys translate_on

endmodule
