module com_sparecell#(
    parameter DFF_N  = 5,
    parameter GATE_N = DFF_N*5
    )(
    input clk,
    input rst_n
    );

`ifndef COM_FPGA
`ifndef PALLADIUM
generate
    genvar gi;
    /* use stdcell spare for eco reseverd */
//------------------------------------------------------------------------------
// DFF.
//------------------------------------------------------------------------------
    // for(gi=0; gi<DFF_N; gi++) begin: SPDFFS
    //     macro_ssdfr  donttouch_sp_u0 ( .D(1'b0), .SI(1'b0), .SCN(1'b0), .CK(1'b0), .RB(1'b0), .Q() );
    // end

//------------------------------------------------------------------------------
// Gate: AND/OR/NAND/XOR/INV/BUFF
//------------------------------------------------------------------------------
    // for(gi=0; gi<GATE_N; gi++) begin: SPGATES
    //     macro_and3   donttouch_sp_an2d3_0  ( .a(1'b0), .b(1'b0), .c(1'b0), .o() );
    //     macro_or3    donttouch_sp_or2d3_0  ( .a(1'b0), .b(1'b0), .c(1'b0), .o() );
    //     macro_nand3  donttouch_sp_nd2d3_0  ( .a(1'b0), .b(1'b0), .c(1'b0), .o() );
    //     macro_xor    donttouch_sp_xord2_0  ( .a(1'b0), .b(1'b0), .o() );
    //     macro_inv    donttouch_sp_invd2_0  ( .a(1'b0), .z() );
    //     macro_buffer donttouch_sp_buffd2_0 ( .A(1'b0), .Z() );
    // end

endgenerate

//------------------------------------------------------------------------------
// Report & Assertion.
//------------------------------------------------------------------------------
`ifdef COM_REPORT_ON
    initial begin
        $display("COM Report: COM sparecell DFF_N=%d, GATE_N=%d, module=%m", DFF_N, GATE_N);
    end
`endif

`endif //PALLADIUM
`endif //COM_FPGA

endmodule
