//////////////////////////////////////////////////////////////////////////////
//
//  Description: ASIC Cells for spram.
//
//  Authors:   wwq, ty
//  Version:   1.0
//
//////////////////////////////////////////////////////////////////////////////

module com_spram_cell#(
    parameter DATA_W                   ,        // Data width of memory. No default value.
    parameter DEPTH                    ,        // Depth of memory. No default value.
    parameter BE_W      = 1            ,        // Byte enable width.
    parameter ADDR_W    = $clog2(DEPTH),        // Address width, extra bits will be truncated.
    parameter MEM_USER  = 0            ,        // Memory user diy
    parameter MCFG_W    = `COM_SYS_W           // Default configuration width. Users can override it for special cases.
    )(
    input                       clk    ,
    input   wire  [MCFG_W-1: 0] mem_cfg,

    input   wire                cen    ,
    input   wire  [BE_W  -1: 0] we     ,
    input   wire  [ADDR_W-1: 0] addr   ,
    input   wire  [DATA_W-1: 0] din    ,
    output  wire  [DATA_W-1: 0] qout   //,
    );

`ifndef COM_RAM_AS_BBOX
`ifdef COM_RAM_AS_REG
    localparam RAM_AS_REG     = 1;
`else
    localparam RAM_AS_REG     = 0;
`endif

    localparam MEM_USE_CELL = DEPTH>=30 && DATA_W*DEPTH>=1024;    // You can change the parameters.

//------------------------------------------------------------------------------
// Ram logic
//------------------------------------------------------------------------------
wire [BE_W-1:0] wr_en = {BE_W{!cen}} & we;
wire rd_en = !cen && !we;
wire use_cell; // use cell as ram.

generate
    if(RAM_AS_REG || !MEM_USE_CELL) begin: USEREG
        com_tpram_reg #(
            .DATA_W (DATA_W ),
            .DEPTH  (DEPTH  ),
            .BE_W   (BE_W   ),
            .ADDR_W (ADDR_W )
            )u_tpram_reg(
            .wr_clk (clk    ),
            .wr_en  (wr_en  ),
            .wr_addr(addr   ),
            .wr_data(din    ),
            .rd_clk (clk    ),
            .rd_en  (rd_en  ),
            .rd_addr(addr   ),
            .rd_data(qout   )
            );
        assign use_cell = 1'b0;
    end
    else begin: USECELL
    /*************************************************************************************************/// Start of user logic.
        // if( DEPTH==1024 && DATA_W==128 && BE_W==1 && MEM_USER==0 )begin
        //     S2RAM1024X128_wrapper t_S2RAM1024X128_wrapper( .CK(clk), .DI(wr_data), .DOUT(rd_data), .RADR(rd_addr), .REN(~rd_en), .WADR(wr_addr), .WEN(~wr_en), .PD(mem_cfg[0]) );
        //     assign use_cell = 1'b1;
        // end
        if(0) begin
            assign use_cell = 1'b1;
        end
    /*************************************************************************************************/// End of user logic.
        else begin: NFOUND
            com_spram_not_found #(
                .DATA_W (DATA_W ),
                .DEPTH  (DEPTH  ),
                .BE_W   (BE_W   ),
                .ADDR_W (ADDR_W )
                )u_tpram_reg(
                .wr_clk (clk    ),
                .wr_en  (wr_en  ),
                .wr_addr(addr   ),
                .wr_data(din    ),
                .rd_clk (clk    ),
                .rd_en  (rd_en  ),
                .rd_addr(addr   ),
                .rd_data(qout   )
                );
            assign use_cell = 1'b0;
        end
    end
endgenerate

//------------------------------------------------------------------------------
// Report & Assertion.
//------------------------------------------------------------------------------

//synopsys translate_off
`ifdef COM_REPORT_ON
    localparam BYTE_W = DATA_W/BE_W;

    integer fp_mem;
    string s;
    string str_size;
    string str_user;
    string str_mem_type;
    initial begin
        str_mem_type = "spram";
        fp_mem = $fopen({"./",str_mem_type,".lst"},"wt");
        $fclose(fp_mem);
    end
    initial begin
        #1;
        fp_mem = $fopen({"./",str_mem_type,".lst"},"at");
        str_user = "";
        if( MEM_USER!=0 )begin
            str_user = $psprintf("_usr%1d", MEM_USER);
        end
        str_size = BE_W==1 ? $psprintf("%1dx%1d",DEPTH,BYTE_W) : $psprintf("%1dx%1dx%1d",DEPTH,BYTE_W,BE_W);
        s = {str_mem_type,str_size,str_user};

        if(use_cell) begin                              // use cell
            $fwrite(fp_mem,"%-20s    Info: normal ram as cell;  %m\n",s);
        end
        else if(!MEM_USE_CELL) begin                    // use reg, in expection (too small)
            $fwrite(fp_mem,"%-20s Message: small memory as dff; %m\n",s);
        end
        else begin                                      // use reg, out of expection
            $fwrite(fp_mem,"%-20s Warning: can't find wrapper;  %m\n",s);
        end
    end
`endif //end of COM_REPORT_ON
//synopsys translate_on

`else
    assign qout = 'b0;
`endif //end of ifdef COM_RAM_AS_BBOX

endmodule
