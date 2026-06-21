//////////////////////////////////////////////////////////////////////////////
//
//  Description: Clock Gating Control.
//
//  Authors:   wwq
//  Version:   2.0
//////////////////////////////////////////////////////////////////////////////

module com_clk_gate(
    input   iena,
    input   iclk,
    output  oclk
    );

`ifdef COM_FPGA
    assign oclk = iclk;
`else
    `ifdef COM_CLKGATE_AS_LATCH
        reg rb_E;
        always @ ( iclk or iena )
        if ( ~iclk )
            rb_E = iena;
        assign oclk = iclk & rb_E;

    `else
        // pmu_clk_gate ginst(
        //     .CK (iclk ),
        //     .E  (iena ),
        //     .TE (1'b0 ),
        //     .QCK(oclk )
        //     );

        /* use stdcell clk gate */
    `endif
`endif

//------------------------------------------------------------------------------
// Report & Assertion.
//------------------------------------------------------------------------------
`ifdef COM_REPORT_ON
    `ifdef COM_CLKGATE_AS_LATCH
        initial begin
            $warning("COM Warning: Use latch as clk gate at %m");
        end
    `endif
`endif

endmodule

