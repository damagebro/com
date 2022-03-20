//////////////////////////////////////////////////////////////////////////////
//
//Function:    Library for fp operations.
//Description:
//
//  Authors:   sht, wwq
//  Version:   1.0
//////////////////////////////////////////////////////////////////////////////

//------------------------------------------------------------------------------
// FP Add/Sub
//------------------------------------------------------------------------------
module com_fpaddsub #(
    parameter FEXP_W = 8,
    parameter FMAN_W = 10,
    parameter DELAY  = 5
    )(
    input  clk   ,
    input  rst_n ,

    input  op    ,
    input  ivld  ,
    input  [FMAN_W+FEXP_W:0]dataa,
    input  [FMAN_W+FEXP_W:0]datab,
    output ovld  ,
    output [FMAN_W+FEXP_W:0]dataz
    );

    localparam FP_W = FMAN_W+FEXP_W+1;
    wire [FP_W-1:0] idata;
    DW_fp_addsub #(
        .sig_width      (FMAN_W ),
        .exp_width      (FEXP_W ),
        .ieee_compliance(0      )
        )addsub_inst(
        .a              (dataa  ),
        .b              (datab  ),
        .rnd            (3'b000 ),
        .op             (op     ),
        .z              (idata  ),
        .status         (       )
        );

    com_fppipe#(
        .DATA_W (FP_W   ),
        .DELAY  (DELAY  )
        )pipe_inst  (
        .clk    (clk    ),
        .rst_n  (rst_n  ),
        .ivld   (ivld   ),
        .idata  (idata  ),
        .ovld   (ovld   ),
        .odata  (dataz  )
        );

endmodule

//------------------------------------------------------------------------------
// FP Mult
//------------------------------------------------------------------------------
module com_fpmul #(
    parameter FEXP_W = 8,
    parameter FMAN_W = 10,
    parameter DELAY  = 3
    )(
    input  clk   ,
    input  rst_n ,

    input  ivld  ,
    input  [FEXP_W+FMAN_W:0]dataa,
    input  [FEXP_W+FMAN_W:0]datab,
    output ovld  ,
    output [FEXP_W+FMAN_W:0]dataz
    );

    localparam FP_W = FMAN_W+FEXP_W+1;
    wire [FEXP_W+FMAN_W:0] idata;
    DW_fp_mult #(
        .sig_width      (FMAN_W ),
        .exp_width      (FEXP_W ),
        .ieee_compliance(0      )
        )mult_inst(
        .a              (dataa  ),
        .b              (datab  ),
        .rnd            (3'b000 ),
        .z              (idata  ),
        .status         (       )
        );

    com_fppipe#(
        .DATA_W (FP_W   ),
        .DELAY  (DELAY  )
        )pipe_inst(
        .clk    (clk    ),
        .rst_n  (rst_n  ),
        .ivld   (ivld   ),
        .idata  (idata  ),
        .ovld   (ovld   ),
        .odata  (dataz  )
        );

endmodule

//------------------------------------------------------------------------------
// FP Div
//------------------------------------------------------------------------------
module com_fpdiv #(
    parameter FEXP_W = 8,
    parameter FMAN_W = 10,
    parameter DELAY  = 8
    )(
    input  clk   ,
    input  rst_n ,

    input  ivld  ,
    input  [FEXP_W+FMAN_W:0]dataa,
    input  [FEXP_W+FMAN_W:0]datab,
    output ovld  ,
    output [FEXP_W+FMAN_W:0]dataz
    );

    localparam FP_W = FMAN_W+FEXP_W+1;
    wire [FEXP_W+FMAN_W:0] idata;
    DW_fp_div #(
        .sig_width      (FMAN_W ),
        .exp_width      (FEXP_W ),
        .ieee_compliance(0      )
        )div_inst(
        .a              (dataa  ),
        .b              (datab  ),
        .rnd            (3'b000 ),
        .z              (idata  ),
        .status         (       )
        );

    com_fppipe#(
        .DATA_W (FP_W   ),
        .DELAY  (DELAY  )
        )pipe_inst(
        .clk    (clk    ),
        .rst_n  (rst_n  ),
        .ivld   (ivld   ),
        .idata  (idata  ),
        .ovld   (ovld   ),
        .odata  (dataz  )
        );

endmodule

//------------------------------------------------------------------------------
// FP Max
//------------------------------------------------------------------------------
module com_fpmax #(
    parameter FEXP_W = 8,
    parameter FMAN_W = 10,
    parameter DELAY  = 3
    )(
    input  clk   ,
    input  rst_n ,

    input  ivld  ,
    input  [FEXP_W+FMAN_W:0]dataa,
    input  [FEXP_W+FMAN_W:0]datab,
    output ovld  ,
    output [FEXP_W+FMAN_W:0]dataz
    );

    localparam FP_W = FMAN_W+FEXP_W+1;
    wire [FEXP_W+FMAN_W:0] idata;
    DW_fp_cmp #(
        .sig_width      (FMAN_W ),
        .exp_width      (FEXP_W ),
        .ieee_compliance(0      )
        )cmp_inst(
        .a              (dataa  ),
        .b              (datab  ),
        .zctr           (1'b1   ),
        .aeqb           (       ),
        .altb           (       ),
        .agtb           (       ),
        .unordered      (       ),
        .z0             (idata  ),
        .z1             (       ),
        .status0        (       ),
        .status1        (       )
        );

    com_fppipe#(
        .DATA_W (FP_W   ),
        .DELAY  (DELAY  )
        )pipe_inst(
        .clk    (clk    ),
        .rst_n  (rst_n  ),
        .ivld   (ivld   ),
        .idata  (idata  ),
        .ovld   (ovld   ),
        .odata  (dataz  )
        );

endmodule

//------------------------------------------------------------------------------
// FP Exp
//------------------------------------------------------------------------------
module com_fpexp #(
    parameter FEXP_W = 8,
    parameter FMAN_W = 10,
    parameter DELAY = 8
    )(
    input  clk   ,
    input  rst_n ,

    input  ivld  ,
    input  [FEXP_W+FMAN_W:0]dataa,
    output ovld  ,
    output [FEXP_W+FMAN_W:0]dataz
    );

    localparam FP_W = FMAN_W+FEXP_W+1;
    wire [FEXP_W+FMAN_W:0] idata;
    DW_fp_exp#(
        .sig_width      (FMAN_W ),
        .exp_width      (FEXP_W ),
        .arch           (2      ),
        .ieee_compliance(0      )
        )exp_inst(
        .a              (dataa  ),
        .z              (idata  ),
        .status         (       )
        );

    com_fppipe#(
        .DATA_W (FP_W   ),
        .DELAY  (DELAY  )
        )pipeo_inst(
        .clk    (clk    ),
        .rst_n  (rst_n  ),
        .ivld   (ivld   ),
        .idata  (idata  ),
        .ovld   (ovld   ),
        .odata  (dataz  )
        );

endmodule

//------------------------------------------------------------------------------
// FP Sqrt
//------------------------------------------------------------------------------
module com_fpsqrt #(
    parameter FEXP_W = 8,
    parameter FMAN_W = 10,
    parameter DELAY  = 8
    )(
    input  clk   ,
    input  rst_n ,

    input  ivld  ,
    input  [FEXP_W+FMAN_W:0]dataa,
    output ovld  ,
    output [FEXP_W+FMAN_W:0]dataz
    );

    localparam FP_W = FMAN_W+FEXP_W+1;
    wire [FEXP_W+FMAN_W:0] idata;
    DW_fp_sqrt #(
        .sig_width      (FMAN_W ),
        .exp_width      (FEXP_W ),
        .ieee_compliance(0      )
        )sqrt_inst(
        .a              (dataa  ),
        .rnd            (3'b000 ),
        .z              (idata  ),
        .status         (       )
        );

    com_fppipe#(
        .DATA_W (FP_W   ),
        .DELAY  (DELAY  )
        )pipe_inst(
        .clk    (clk    ),
        .rst_n  (rst_n  ),
        .ivld   (ivld   ),
        .idata  (idata  ),
        .ovld   (ovld   ),
        .odata  (dataz  )
        );

endmodule

//------------------------------------------------------------------------------
// FP<->int conversion
//------------------------------------------------------------------------------
module com_int2fp #(
    parameter FEXP_W = 8,
    parameter FMAN_W = 10,
    parameter ISIZE  = 9,
    parameter DELAY  = 3
    )(
    input  clk   ,
    input  rst_n ,

    input  ivld  ,
    input  [ISIZE-1:0]dataa,
    output ovld  ,
    output [FEXP_W+FMAN_W:0]dataz
    );

    localparam FP_W = FMAN_W+FEXP_W+1;
    wire [FEXP_W+FMAN_W:0] idata;
    DW_fp_i2flt #(
        .sig_width  (FMAN_W ),
        .exp_width  (FEXP_W ),
        .isize      (ISIZE  ),
        .isign      (1      )
        )i2flt_inst(
        .a          (dataa  ),
        .rnd        (3'b000 ),
        .z          (idata  ),
        .status     (       )
        );

    com_fppipe#(
        .DATA_W (FP_W   ),
        .DELAY  (DELAY  )
        )pipe_inst(
        .clk    (clk    ),
        .rst_n  (rst_n  ),
        .ivld   (ivld   ),
        .idata  (idata  ),
        .ovld   (ovld   ),
        .odata  (dataz  )
        );

endmodule

module com_fp2int #(
    parameter FEXP_W = 8,
    parameter FMAN_W = 10,
    parameter ISIZE  = 9,
    parameter DELAY  = 3
    )(
    input  clk   ,
    input  rst_n ,

    input  ivld  ,
    input  [FEXP_W+FMAN_W:0]dataa,
    output ovld  ,
    output [ISIZE-1:0]dataz
    );
    wire [ISIZE-1:0] idata;
    DW_fp_flt2i #(
        .sig_width      (FMAN_W ),
        .exp_width      (FEXP_W ),
        .isize          (ISIZE  ),
        .ieee_compliance(0      )
        )flt2i_inst(
        .a              (dataa  ),
        .rnd            (3'b000 ),
        .z              (idata  ),
        .status         (       )
        );

    com_fppipe#(
        .DATA_W (ISIZE  ),
        .DELAY  (DELAY  )
        )pipe_inst(
        .clk    (clk    ),
        .rst_n  (rst_n  ),
        .ivld   (ivld   ),
        .idata  (idata  ),
        .ovld   (ovld   ),
        .odata  (dataz  )
        );

endmodule

//------------------------------------------------------------------------------
// FP<->fix conversion: fix value = coef*2^exps (signed value)
//------------------------------------------------------------------------------
module com_fix2fp #(
    parameter FEXP_W = 8,
    parameter FMAN_W = 10,
    parameter IEXPS_W= 7,
    parameter ICOEF_W= 9,
    parameter DELAY  = 3
    )(
    input  clk   ,
    input  rst_n ,

    input  ivld  ,
    input  [IEXPS_W-1:0] expsa,
    input  [ICOEF_W-1:0] coefa,
    output ovld  ,
    output [FEXP_W+FMAN_W:0] dataz
    );

    localparam CEXP_W = $clog2(ICOEF_W)+1;                              // Enough to put int value.
    localparam ATMP_W = CEXP_W>FEXP_W?CEXP_W:FEXP_W;
    localparam AEXP_W = (ATMP_W>IEXPS_W?ATMP_W:IEXPS_W)+2;              // Enough after add bias (signed value).

    // Step1: convert to large fp (enough to put int value without Nan/Inf).
    logic              signc;
    logic [CEXP_W-1:0] expnc;
    logic [FMAN_W-1:0] mantc;

    DW_fp_i2flt #(
        .sig_width(FMAN_W   ),
        .exp_width(CEXP_W   ),
        .isize    (ICOEF_W  ),
        .isign    (1        )
        )i2flt_inst(
        .a        (coefa    ),
        .rnd      (3'b000   ),
        .z        ({signc, expnc, mantc}),
        .status   (         )
        );

    // Step2: add bias to expn & handle special output fp.
    logic              signr;
    logic [FEXP_W-1:0] expnr;
    logic [FMAN_W-1:0] mantr;

    wire  [AEXP_W-1:0] expn_add = (AEXP_W)'(expnc) + (AEXP_W)'(2**(FEXP_W-1) - 2**(CEXP_W-1)) + {{(AEXP_W-IEXPS_W+1){expsa[IEXPS_W-1]}}, expsa[IEXPS_W-2:0]};
    always_comb
    if(coefa=='0 || expn_add[AEXP_W-1] || expn_add=='0) begin       // Zero/denorm => 0
        signr = '0;
        expnr = '0;
        mantr = '0;
    end
    else if(expn_add >= (AEXP_W)'(2**FEXP_W-1)) begin               // Nan/Inf => NormMax
        signr = signc;
        expnr = {FEXP_W{1'b1}}-(FEXP_W)'(1);
        mantr = {FMAN_W{1'b1}};
    end
    else begin
        signr = signc;
        expnr = expn_add[FEXP_W-1:0];
        mantr = mantc;
    end

    // Step3: pipeline.
    com_fppipe#(
        .DATA_W (FEXP_W+FMAN_W+1),
        .DELAY  (DELAY  )
        )pipe_inst(
        .clk    (clk    ),
        .rst_n  (rst_n  ),
        .ivld   (ivld   ),
        .idata  ({signr, expnr, mantr}),
        .ovld   (ovld   ),
        .odata  (dataz  )
        );

endmodule

module com_fp2fix#(
    parameter FEXP_W  = 8,
    parameter FMAN_W  = 10,
    parameter IEXPS_W = 7,
    parameter ICOEF_W = 9,
    parameter DELAY   = 3
    )(
    input  clk   ,
    input  rst_n ,

    input  ivld  ,
    input  [FEXP_W+FMAN_W:0] dataa,
    input  [IEXPS_W-1:0] expsz,
    output ovld  ,
    output [ICOEF_W-1:0] coefz
    );

    localparam CEXP_W = (FEXP_W>IEXPS_W?FEXP_W:IEXPS_W) + 1;  // Enough after add bias (unsigned value).
    // Step1: sub bias to expn & handle special input fp.
    logic              signi;
    logic [FEXP_W-1:0] expni;
    logic [FMAN_W-1:0] manti;

    logic              signc;
    logic [CEXP_W-1:0] expnc;
    logic [FMAN_W-1:0] mantc;

    assign {signi, expni, manti} = dataa;

    always_comb
    if(expni=='0) begin
        signc = '0;
        expnc = '0;
        mantc = '0;
    end
    else if(expni==(FEXP_W)'(2**FEXP_W-1)) begin
        signc = signi;
        expnc = {CEXP_W{1'b1}}-(CEXP_W)'(1);
        mantc = {FMAN_W{1'b1}};
    end
    else begin
        signc = signi;
        expnc = (CEXP_W)'(expni) + (CEXP_W)'(2**(CEXP_W-1) - 2**(FEXP_W-1)) - {{(CEXP_W-IEXPS_W+1){expsz[IEXPS_W-1]}}, expsz[IEXPS_W-2:0]};
        mantc = manti;
    end

    // Step 2: convert to int.
    wire [ICOEF_W-1:0] idata;
    DW_fp_flt2i #(
        .sig_width      (FMAN_W ),
        .exp_width      (CEXP_W ),
        .isize          (ICOEF_W),
        .ieee_compliance(0      )
        )flt2i_inst(
        .a              ({signc, expnc, mantc}),
        .rnd            (3'b000 ),
        .z              (idata  ),
        .status         (       )
        );

    // Step 3: pipe.
    com_fppipe#(
        .DATA_W (ICOEF_W),
        .DELAY  (DELAY  )
        )pipe_inst(
        .clk    (clk    ),
        .rst_n  (rst_n  ),
        .ivld   (ivld   ),
        .idata  (idata  ),
        .ovld   (ovld   ),
        .odata  (coefz  )
        );

endmodule

//------------------------------------------------------------------------------
// Width conversion
//------------------------------------------------------------------------------
module com_fpwiden#(
    parameter IEXP_W = 5,
    parameter IMAN_W = 10,
    parameter OEXP_W = 8,
    parameter OMAN_W = 10
    )(
    input   [IEXP_W+IMAN_W:0] idata,
    output  [OEXP_W+OMAN_W:0] odata
    );

    localparam EXPN_ALIGN =  ((1<<(OEXP_W-1))-1) - ((1<<(IEXP_W-1))-1);

    logic              isign;
    logic [IEXP_W-1:0] iexpn;
    logic [IMAN_W-1:0] imant;

    logic              osign;
    logic [OEXP_W-1:0] oexpn;
    logic [OMAN_W-1:0] omant;
    logic [OMAN_W-1:0] omant_ext;
    logic [OMAN_W-1:0] omant_max;

    assign {isign, iexpn, imant} = idata;
    assign odata = {osign, oexpn, omant};

    generate
        if(OMAN_W==IMAN_W) begin
            assign omant_ext = imant;
            assign omant_max = {(OMAN_W){1'b1}};
        end
        else begin
            assign omant_ext = {imant, (OMAN_W-IMAN_W)'(0)};
            assign omant_max = {{(IMAN_W){1'b1}}, (OMAN_W-IMAN_W)'(0)};
        end
    endgenerate

    //expn
    always_comb begin
        if(~|iexpn)begin                //zero & denorm
           oexpn    = '0;
           omant    = '0;
        end
        else if(&iexpn)begin            //Inf or Nan => NormMax in FP_I
           oexpn    = iexpn + EXPN_ALIGN - 1;
           omant    = omant_max;
        end else begin
           oexpn    = iexpn + EXPN_ALIGN;
           omant    = omant_ext;
        end
        osign       = isign;
    end
endmodule

module com_fpshrink#(
    parameter IEXP_W = 8,
    parameter IMAN_W = 10,
    parameter OEXP_W = 5,
    parameter OMAN_W = 10
    )(
    input   [IEXP_W+IMAN_W:0] idata,
    output  [OEXP_W+OMAN_W:0] odata
    );

    localparam EXPN_TH0 = ((1<<(IEXP_W-1))-1) - ((1<<(OEXP_W-1))-1);
    localparam EXPN_TH1 = ((1<<(IEXP_W-1))-1) + ((1<<(OEXP_W-1))-1) + 1;

    logic              isign;
    logic [IEXP_W-1:0] iexpn;
    logic [IMAN_W-1:0] imant;
    logic              osign;
    logic [OEXP_W-1:0] oexpn;
    logic [OMAN_W-1:0] omant;
    logic              omant_inc;

    assign {isign, iexpn, imant} = idata;
    assign odata = {osign, oexpn, omant};

    generate
        if(OMAN_W==IMAN_W) begin
            assign omant_inc = 1'b0;
        end
        else if(OMAN_W==IMAN_W-1) begin
            assign omant_inc = imant[IMAN_W-OMAN_W-1] & imant[IMAN_W-OMAN_W];
        end
        else begin
            assign omant_inc = imant[IMAN_W-OMAN_W-1]&(imant[IMAN_W-OMAN_W]|(|imant[IMAN_W-OMAN_W-2:0]));
        end
    endgenerate

    always_comb begin
        if(iexpn<=EXPN_TH0)begin                        // zero/denorm/small number
           oexpn    = '0;
           omant    = '0;
        end else if(iexpn>=EXPN_TH1) begin              // Nan/Inf/Big number => NormMax in FP_O
           oexpn    = {(OEXP_W){1'b1}}-1;
           omant    = '1;
        end else begin
            if(omant_inc)begin
                if(&imant[IMAN_W-1:IMAN_W-OMAN_W])begin // Round with exp inc to inf/no-inf
                    if(iexpn - EXPN_TH0 + 1 == {(OEXP_W){1'b1}})begin
                       oexpn = iexpn - EXPN_TH0;
                       omant = {(OMAN_W){1'b1}};
                    end else begin
                       oexpn = iexpn - EXPN_TH0 + 1;
                       omant = '0;
                    end
                end else begin                          // Round without exp inc
                    oexpn = iexpn - EXPN_TH0;
                    omant = imant[IMAN_W-1:IMAN_W-OMAN_W] + 1;
                end
            end
            else begin                                  // Rounding no inc
                oexpn   = iexpn - EXPN_TH0;
                omant   = imant[IMAN_W-1:IMAN_W-OMAN_W];
            end
        end
        osign = isign;
    end

endmodule

//------------------------------------------------------------------------------
// Data pipeline.
//------------------------------------------------------------------------------
module com_fppipe#(
    parameter DATA_W = 16,
    parameter DELAY  = 3
    )(
    input   clk ,
    input   rst_n,

    input   ivld,
    input   [DATA_W-1:0] idata,
    output  ovld,
    output  [DATA_W-1:0] odata
    );

    generate
    if(DELAY == 0) begin: NODELAY
        assign  ovld = ivld;
        assign  odata= idata;
    end
    else begin: SHIFT
        logic [DELAY:0] vld_p;
        logic [DELAY:0][DATA_W-1:0] data_p;

        assign vld_p[0]  = ivld;
        assign data_p[0] = idata;
        always@(posedge clk or negedge rst_n)
        if(!rst_n) begin
            vld_p[DELAY:1] <= '0;
        end
        else begin
            vld_p[DELAY:1] <= vld_p[DELAY-1:0];
        end

        always@(posedge clk or negedge rst_n)
        if(!rst_n) for(int i=1; i<=DELAY; i++) begin
            data_p[i] <= '0;
        end
        else for(int i=1; i<=DELAY; i++) if (|vld_p[DELAY-1:0])  begin
            data_p[i] <= data_p[i-1];
        end

        assign ovld = vld_p[DELAY];
        assign odata= data_p[DELAY];
    end
    endgenerate

endmodule
